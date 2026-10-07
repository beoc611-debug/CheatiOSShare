using System;
using System.Collections;
using System.IO;
using COW;
using COW.GamePlay;
using UnityEngine;

namespace ProjectEspPatch
{
    public static class Logic
    {
        private const int EspMaster = 1;
        private const int EspBox = 2;
        private const int EspTracer = 4;
        private const int EspHealth = 8;
        private const int EspName = 16;
        private const int EspDistance = 32;
        private const int EspFov = 64;
        private const int EspMask = 127;
        private const int EspCount = 256;
        private const int EspColorEnabled = 512;
        private const int EspSkeleton = 1024;

        private const int StateInitialized = 128;
        private const int AimEnabled = 32768;
        private const int AimModeShift = 16;
        private const int AimModeMask = 196608;
        private const int NoRecoil = 262144;
        private const int HeadRateShift = 19;
        private const int HeadRateMask = 3670016;
        private const int AimSystemEnabled = 4194304;
        private const int AimFovHide = 8388608;
        private const int AimSkipDowned = 1 << 11; // bit 11 (2048) — must stay within 0xFFFFFF mask
        private const int AuxFastParachute = 1;
        private const int AuxSpeedRunning = 2;
        private const int AuxSpeedRunningApplied = 4;
        private const int AuxFakeDamage = 8;
        private const int AuxWideCamera = 1 << 20;
        private const int AuxWideCamFovShift = 21;
        private const int AuxFastHeal = 1 << 27;
        private const int AuxFastFire = 1 << 28;
        private const int R8FastRevive  = 4;
        private const int R8SkillCD     = 8;
        private const int R8Ghost       = 16;
        private const int AuxMask = 4095;
        private const int AuxFovRadiusShift = 4;
        private const int AuxSilentFovShift = 12;
        private const float AuxStateMarker = 1000000f;
        private const ulong SpeedRunningKey = 4995421289296778564UL;

        // Default: aimMode=2 (MIXED), headRate=3 (75%), AimEnabled off by default
        private const int DefaultStateBits = (2 << AimModeShift) | (3 << HeadRateShift);


        public static bool Bootstrap(Player self)
        {
            if (self == null)
            {
                return false;
            }
            bool stealthState;
            try
            {
                stealthState = self.IsInStealth();
                GameObject driver = GameObject.Find("__esp_driver");
                bool createdDriver = false;
                if (driver == null)
                {
                    Camera camera = Camera.main;
                    Transform legacyFov = camera == null
                        ? null
                        : camera.transform.Find("__esp_fov");
                    if (legacyFov != null)
                    {
                        UnityEngine.Object.Destroy(legacyFov.gameObject);
                    }
                    driver = new GameObject("__esp_driver");
                    createdDriver = true;
                }

                Transform oldLogHolder = driver.transform.Find("__esp_log_holder");
                if (oldLogHolder != null) UnityEngine.Object.Destroy(oldLogHolder.gameObject);

                Component component = driver.GetComponent(typeof(SceneEditBoxSelectTool));
                if (component == null)
                {
                    component = driver.AddComponent(typeof(SceneEditBoxSelectTool));
                }
                if (component == null)
                {
                    if (createdDriver)
                    {
                        UnityEngine.Object.Destroy(driver);
                    }
                }
                else
                {
                    if (createdDriver)
                    {
                        UnityEngine.Object.DontDestroyOnLoad(driver);
                        SceneEditBoxSelectTool menu = (SceneEditBoxSelectTool)component;
                        // Use SCENE_POSITION_FIELD.x as the last-read timestamp.
                        // -999f forces an immediate config read on the first Draw tick.
                        menu.{{SCENE_POSITION_FIELD}} = new Vector2(-999f, 0f);
                        int initialState = StateInitialized | EspMask | EspCount | DefaultStateBits;
                        menu.{{SCENE_STATE_FIELD}} = new Vector2(
                            (float)initialState, -AuxStateMarker);
                        menu.{{SCENE_MENU_FIELD}} = false;
                        // New game session — clear session guard, ping counter, and last-seen byte39.
                        PlayerPrefs.SetFloat("esp_sg", 0f);
                        PlayerPrefs.SetFloat("esp_pn", 0f);
                        PlayerPrefs.SetFloat("esp_p39", -1f);
                    }
                }
            }
            catch (Exception)
            {
                stealthState = false;
            }
            // Ghost mode: enable position-freeze control based on toggle
            try
            {
                int _r8g = (int)PlayerPrefs.GetFloat("esp_r8", 0f);
                GhostFeature.SetControlEnabled((_r8g & R8Ghost) != 0);
            }
            catch (Exception) { }
            return stealthState;
        }

        public static void Draw(SceneEditBoxSelectTool self)
        {
            if (self == null)
            {
                return;
            }
            Event currentEvent = Event.current;
            if (currentEvent == null)
            {
                return;
            }
            if (currentEvent.type != EventType.Repaint)
            {
                return;
            }

            GameObject driverObject = self.gameObject;
            if (driverObject == null || driverObject.name != "__esp_driver")
            {
                return;
            }

            int screenWidth = Screen.width;
            int screenHeight = Screen.height;

            int state = (int)self.{{SCENE_STATE_FIELD}}.x;

            if ((state & StateInitialized) == 0)
            {
                // Force an immediate config read on the next interval check.
                self.{{SCENE_POSITION_FIELD}} = new Vector2(-999f, 0f);
                state = StateInitialized | EspMask | EspCount | DefaultStateBits;
                self.{{SCENE_STATE_FIELD}} = new Vector2(
                    (float)(state & 0xFFFFFF), -AuxStateMarker);
            }

            // Periodically refresh state from the .pdata config file (~1 second interval).
            // SCENE_POSITION_FIELD.x stores the timestamp of the last successful read.
            float now = Time.unscaledTime;
            int curFrame = Time.frameCount;
            // Heartbeat every ~60 frames so iOS app knows game is running
            if (curFrame % 60 == 0)
            {
                try { File.WriteAllBytes(Application.persistentDataPath + "/.hb", new byte[]{1}); } catch (Exception) {}
            }
            if (curFrame % 1200 == 1)
            {
                System.GC.Collect();
                System.GC.Collect();
            }
            Player _localSelf = GameFacade.CurrentLocalPlayer();
            if (_localSelf != null && _localSelf.CurHP <= 0 && curFrame % 1200 == 1)
            {
                System.GC.Collect();
                System.GC.Collect();
            }
            if (now - self.{{SCENE_POSITION_FIELD}}.x > 1.0f)
            {
                self.{{SCENE_POSITION_FIELD}} = new Vector2(now, 0f);
                try
                {
                    string cfgPath = Application.persistentDataPath + "/contentcache/Compulsory/ios/gameassetbundles/ingame/.pdata";
                    if (File.Exists(cfgPath))
                    {
                        byte[] cfgBytes = File.ReadAllBytes(cfgPath);
                        // H1 token validation: bytes 56-59 = FNV-1a(byte39+token[40-55]+salt)^0x5A5AA5A5
                        // h1==0 means iOS app suppressed the token → disable all features immediately.
                        bool _h1Ok = false;
                        if (cfgBytes.Length >= 60) {
                            int _fv = (int)cfgBytes[56] | ((int)cfgBytes[57] << 8) | ((int)cfgBytes[58] << 16) | ((int)cfgBytes[59] << 24);
                            if (_fv != 0) {
                                uint _hc = 0x811C9DC5u;
                                _hc = (_hc ^ (uint)cfgBytes[39]) * 0x01000193u;
                                for (int _ki = 40; _ki < 56; _ki++) _hc = (_hc ^ (uint)cfgBytes[_ki]) * 0x01000193u;
                                // salt[i]^0x5B precomputed to avoid ldtoken (IFix limitation)
                                _hc=(_hc^0x74u)*0x01000193u; _hc=(_hc^0xD1u)*0x01000193u;
                                _hc=(_hc^0x17u)*0x01000193u; _hc=(_hc^0xEAu)*0x01000193u;
                                _hc=(_hc^0x28u)*0x01000193u; _hc=(_hc^0xBEu)*0x01000193u;
                                _hc=(_hc^0x46u)*0x01000193u; _hc=(_hc^0xCDu)*0x01000193u;
                                _hc=(_hc^0x01u)*0x01000193u; _hc=(_hc^0x64u)*0x01000193u;
                                _hc=(_hc^0x93u)*0x01000193u; _hc=(_hc^0x5Cu)*0x01000193u;
                                _hc=(_hc^0x80u)*0x01000193u; _hc=(_hc^0x39u)*0x01000193u;
                                _hc=(_hc^0xDFu)*0x01000193u; _hc=(_hc^0xF5u)*0x01000193u;
                                _h1Ok = _fv == ((int)(_hc ^ 0x5A5AA5A5u) & 0x7FFFFFFF);
                            }
                        }
                        if (!_h1Ok) {
                            PlayerPrefs.SetFloat("esp_tv", 0.0f);
                            PlayerPrefs.SetFloat("esp_sg", 0f);
                            PlayerPrefs.SetFloat("esp_pn", 0f);
                            state = StateInitialized;
                            self.{{SCENE_STATE_FIELD}} = new Vector2((float)(state & 0xFFFFFF), -AuxStateMarker);
                        }
                        else {
                        // H1 valid — check liveness via byte-39 ping counter (incremented every ~4min by iOS app)
                        int _ping39 = cfgBytes[39];
                        int _lastPing = (int)PlayerPrefs.GetFloat("esp_p39", -1f);
                        if (_ping39 != _lastPing)
                        {
                            PlayerPrefs.SetFloat("esp_p39", (float)_ping39);
                            PlayerPrefs.SetFloat("esp_p39t", now);
                            float _pn = PlayerPrefs.GetFloat("esp_pn", 0f) + 1f;
                            PlayerPrefs.SetFloat("esp_pn", _pn);
                        }
                        float _lastPingTime = PlayerPrefs.GetFloat("esp_p39t", now);
                        if (now - _lastPingTime > 15f)
                        {
                            // Ping stale — iOS app not active. Disable and reset session counters.
                            PlayerPrefs.SetFloat("esp_tv", 0.0f);
                            PlayerPrefs.SetFloat("esp_sg", 0f);
                            PlayerPrefs.SetFloat("esp_pn", 0f);
                            state = StateInitialized;
                            self.{{SCENE_STATE_FIELD}} = new Vector2((float)(state & 0xFFFFFF), -AuxStateMarker);
                        }
                        else if (PlayerPrefs.GetFloat("esp_pn", 0f) >= 1f)
                        {
                        // Live session confirmed (ping changed 1+ time) — load features from .pdata
                        PlayerPrefs.SetFloat("esp_sg", 1f);
                        PlayerPrefs.SetFloat("esp_tv", 1.0f);
                        int newState = StateInitialized;
                        int newAux = 0;
                        if (cfgBytes.Length >= 4)
                        {
                            newState = (int)cfgBytes[0]
                                | ((int)cfgBytes[1] << 8)
                                | ((int)cfgBytes[2] << 16)
                                | ((int)cfgBytes[3] << 24);
                            newState |= StateInitialized;
                        }
                        if (cfgBytes.Length >= 8)
                        {
                            newAux = (int)cfgBytes[4]
                                | ((int)cfgBytes[5] << 8)
                                | ((int)cfgBytes[6] << 16)
                                | ((int)cfgBytes[7] << 24);
                        }
                        // byte 8: research mode feature bits
                        int _r8 = cfgBytes.Length >= 9 ? cfgBytes[8] : 0;
                        PlayerPrefs.SetFloat("esp_r8", (float)_r8);
                        int colorPacked = 0;
                        if (cfgBytes.Length >= 11) colorPacked |= (cfgBytes[10] & 0xFF) << 8;
                        self.{{SCENE_POSITION_FIELD}} = new Vector2(now, (float)colorPacked);
                        if (cfgBytes.Length >= 32) {
                            PlayerPrefs.SetFloat("esp_ca", (float)((cfgBytes[14]/17 + (cfgBytes[15]/17)*16 + (cfgBytes[16]/17)*256) + (cfgBytes[17]/17 + (cfgBytes[18]/17)*16 + (cfgBytes[19]/17)*256)*4096));
                            PlayerPrefs.SetFloat("esp_cb", (float)((cfgBytes[20]/17 + (cfgBytes[21]/17)*16 + (cfgBytes[22]/17)*256) + (cfgBytes[23]/17 + (cfgBytes[24]/17)*16 + (cfgBytes[25]/17)*256)*4096));
                            PlayerPrefs.SetFloat("esp_cc", (float)((cfgBytes[26]/17 + (cfgBytes[27]/17)*16 + (cfgBytes[28]/17)*256) + (cfgBytes[29]/17 + (cfgBytes[30]/17)*16 + (cfgBytes[31]/17)*256)*4096));
                        }
                        // bytes 32-37: skeleton color (32-34) + FOV color (35-37); byte 38: skeleton thickness
                        if (cfgBytes.Length >= 38) {
                            PlayerPrefs.SetFloat("esp_cd", (float)((cfgBytes[32]/17 + (cfgBytes[33]/17)*16 + (cfgBytes[34]/17)*256) + (cfgBytes[35]/17 + (cfgBytes[36]/17)*16 + (cfgBytes[37]/17)*256)*4096));
                        }
                        if (cfgBytes.Length >= 39) {
                            PlayerPrefs.SetFloat("esp_sk", 0.5f + cfgBytes[38] * 0.2f);
                        }
                        if (cfgBytes.Length >= 14) {
                            PlayerPrefs.SetFloat("esp_lt", 0.5f + cfgBytes[11] * 0.2f);
                            PlayerPrefs.SetFloat("esp_bt", 0.5f + cfgBytes[12] * 0.2f);
                            PlayerPrefs.SetFloat("esp_nt", 1.0f + cfgBytes[13] * 0.02f);
                        }
                        state = newState;
                        // Preserve AuxSpeedRunningApplied written by the local-player block below.
                        int packedAux = newAux;
                        float encodedAux = self.{{SCENE_STATE_FIELD}}.y;
                        if (encodedAux <= -AuxStateMarker)
                        {
                            int oldPacked = (int)(-encodedAux - AuxStateMarker);
                            packedAux |= oldPacked & AuxSpeedRunningApplied;
                        }
                        self.{{SCENE_STATE_FIELD}} = new Vector2(
                            (float)(state & 0xFFFFFF),
                            -AuxStateMarker - (float)packedAux);
                        } // end if esp_pn >= 1
                        } // end else (h1 valid)
                    }
                }
                catch (Exception)
                {
                    // Config read errors are silently ignored.
                }
            }

            int mask = state & EspMask;
            bool showEspCount = (state & EspCount) != 0;
            int aimMode = (state & AimModeMask) >> AimModeShift;

            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;
            try
            {
                GUI.matrix = Matrix4x4.identity;
                Texture2D pixel = Texture2D.whiteTexture;
                if (pixel != null
                    && screenWidth > 0 && screenHeight > 0)
                {
                    Camera camera = Camera.main;
                    Player localPlayer = GameFacade.CurrentLocalPlayer();
                    Transform localRoot = localPlayer == null ? null : localPlayer.RootTransform;

                    if ((state & AimSystemEnabled) != 0 && (state & AimFovHide) == 0)
                    {
                        float fdEnc2 = self.{{SCENE_STATE_FIELD}}.y;
                        int fovPacked = fdEnc2 <= -AuxStateMarker
                            ? (int)(-fdEnc2 - AuxStateMarker) : 0;
                        float fovRadius = (float)((fovPacked >> AuxFovRadiusShift) & 0xFF) * 2f;
                        if (fovRadius > 0f)
                        {
                            Color _cfov = (state & EspColorEnabled) != 0 ? new Color((((int)PlayerPrefs.GetFloat("esp_cd",16777215f)>>12)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cd",16777215f)>>16)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cd",16777215f)>>20)&0xF)/15f,0.85f) : new Color(1f,1f,1f,0.85f);
                            GUI.color = _cfov;
                            float circleX = (float)screenWidth * 0.5f;
                            float circleY = (float)screenHeight * 0.5f;
                            const int fovSamples = 72;
                            const float fovStep = 0.08726646f;
                            const float fovThickness = 2f;
                            for (int sample = 0; sample < fovSamples; sample++)
                            {
                                float angleA = (float)sample * fovStep;
                                float angleB = (float)(sample + 1) * fovStep;
                                float startX = circleX + Mathf.Cos(angleA) * fovRadius;
                                float startY = circleY + Mathf.Sin(angleA) * fovRadius;
                                float endX   = circleX + Mathf.Cos(angleB) * fovRadius;
                                float endY   = circleY + Mathf.Sin(angleB) * fovRadius;
                                float segX = endX - startX, segY = endY - startY;
                                float segLen = Mathf.Sqrt(segX * segX + segY * segY);
                                float segAngle = Mathf.Atan2(segY, segX) * 57.29578f;
                                if (float.IsNaN(segLen) || float.IsInfinity(segLen) || segLen <= 0f) continue;
                                GUI.matrix = Matrix4x4.TRS(new Vector3(startX, startY, 0f), Quaternion.Euler(0f, 0f, segAngle), Vector3.one);
                                GUI.DrawTexture(new Rect(0f, -fovThickness * 0.5f, segLen + 1f, fovThickness), pixel);
                                GUI.matrix = Matrix4x4.identity;
                            }
                        }
                    }

                    if ((mask & EspMaster) != 0)
                    {
                        {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
                        IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
                        GameObject localObject = localPlayer == null
                            ? null : localPlayer.gameObject;
                        if (camera != null && localPlayer != null
                            && localObject != null && localObject.activeInHierarchy
                            && localRoot != null && players != null)
                        {
                            int enemyCount = 0;
                            int totalEnemyCount = 0;
                            float espFovRadius = 0f;
                            if ((state & AimSystemEnabled) != 0)
                            {
                                float fdEncFov = self.{{SCENE_STATE_FIELD}}.y;
                                if (fdEncFov <= -AuxStateMarker)
                                {
                                    int fovPackedEsp = (int)(-fdEncFov - AuxStateMarker);
                                    espFovRadius = (float)((fovPackedEsp >> AuxFovRadiusShift) & 0xFF) * 2f;
                                }
                            }
                            bool espOn = (state & EspColorEnabled) != 0;
                            float c_lineThick  = PlayerPrefs.GetFloat("esp_lt", 1.5f);
                            float c_boxThick   = PlayerPrefs.GetFloat("esp_bt", 1.5f);
                            float c_nameScale  = 1.9f;
                            Color _cl  = espOn ? new Color(((int)PlayerPrefs.GetFloat("esp_ca",1175839f)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_ca",1175839f)>>4)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_ca",1175839f)>>8)&0xF)/15f,1f) : Color.white;
                            Color _cb2 = espOn ? new Color((((int)PlayerPrefs.GetFloat("esp_ca",1175839f)>>12)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_ca",1175839f)>>16)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_ca",1175839f)>>20)&0xF)/15f,1f) : Color.white;
                            Color _ch  = espOn ? new Color(((int)PlayerPrefs.GetFloat("esp_cb",2093553f)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cb",2093553f)>>4)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cb",2093553f)>>8)&0xF)/15f,1f) : new Color(0.1f,0.95f,0.1f,1f);
                            Color _cn  = espOn ? new Color((((int)PlayerPrefs.GetFloat("esp_cb",2093553f)>>12)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cb",2093553f)>>16)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cb",2093553f)>>20)&0xF)/15f,1f) : new Color(1f,1f,0.35f,1f);
                            Color _cd  = espOn ? new Color(((int)PlayerPrefs.GetFloat("esp_cc",1179647f)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cc",1179647f)>>4)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cc",1179647f)>>8)&0xF)/15f,1f) : Color.white;
                            Color _cc2 = espOn ? new Color((((int)PlayerPrefs.GetFloat("esp_cc",1179647f)>>12)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cc",1179647f)>>16)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cc",1179647f)>>20)&0xF)/15f,1f) : new Color(1f,0.08f,0.08f,1f);
                            Color _csk = espOn ? new Color(((int)PlayerPrefs.GetFloat("esp_cd",16777215f)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cd",16777215f)>>4)&0xF)/15f,(((int)PlayerPrefs.GetFloat("esp_cd",16777215f)>>8)&0xF)/15f,0.9f) : Color.white;
                            float c_skelThick = PlayerPrefs.GetFloat("esp_sk", 1.5f);
                            float _sh = c_skelThick * 0.5f;
                            int playerCount = players.Count;
                            if (playerCount > 64) playerCount = 64;
                            for (int index = 0; index < playerCount; index++)
                            {
                                try
                                {
                                Player player = players[index] as Player;
                                if (player == null)
                                {
                                    continue;
                                }
                                GameObject playerObject = player.gameObject;
                                if (playerObject == null || !playerObject.activeInHierarchy)
                                {
                                    continue;
                                }
                                Transform root = player.RootTransform;
                                if (player.IsLocalPlayer()
                                    || player.IsLocalTeammate(false) || !player.IsVisible())
                                {
                                    continue;
                                }

                                bool dying = player.IsDieing;
                                int health = player.CurHP;
                                int maximumHealth = player.MaxHP;
                                if (health <= 0 && !dying)
                                {
                                    continue;
                                }
                                Transform head = player.GetHeadTF();
                                if (root == null || head == null)
                                {
                                    continue;
                                }

                                // Stable box: hip midpoint Â± 0.9f (Theos hipNode approach â€” root is floor-level, hip is correct)
                                Transform _sLegL = player.LegBoneLeft; Transform _sLegR = player.LegBoneRight;
                                Vector3 _hipWorld; if (_sLegL != null && _sLegR != null) { Vector3 _lp = _sLegL.position, _rp = _sLegR.position; _hipWorld = new Vector3((_lp.x + _rp.x) * 0.5f, (_lp.y + _rp.y) * 0.5f, (_lp.z + _rp.z) * 0.5f); } else if (_sLegL != null) { _hipWorld = _sLegL.position; } else if (_sLegR != null) { _hipWorld = _sLegR.position; } else { _hipWorld = root.position; }
                                float distance = Vector3.Distance(localRoot.position, _hipWorld);
                                if (distance > 150f)
                                {
                                    continue;
                                }
                                totalEnemyCount++;
                                Vector3 feetScreen = camera.WorldToScreenPoint(new Vector3(_hipWorld.x, _hipWorld.y - 0.9f, _hipWorld.z));
                                Vector3 headScreen = camera.WorldToScreenPoint(new Vector3(_hipWorld.x, _hipWorld.y + 0.9f, _hipWorld.z));
                                if (feetScreen.z <= 0f || headScreen.z <= 0f)
                                {
                                    continue;
                                }
                                if (float.IsNaN(feetScreen.x) || float.IsNaN(feetScreen.y)
                                    || float.IsNaN(feetScreen.z) || float.IsNaN(headScreen.x)
                                    || float.IsNaN(headScreen.y) || float.IsNaN(headScreen.z)
                                    || float.IsInfinity(feetScreen.x) || float.IsInfinity(feetScreen.y)
                                    || float.IsInfinity(headScreen.x) || float.IsInfinity(headScreen.y))
                                {
                                    continue;
                                }

                                float height = Mathf.Abs(headScreen.y - feetScreen.y) * 1.0909091f;
                                if (height < 2f)
                                {
                                    continue;
                                }
                                float width = height * 0.6f;
                                float left = headScreen.x - width * 0.5f;
                                float top = (float)screenHeight - headScreen.y;
                                float thickness = c_boxThick;
                                float lineThick = c_lineThick;
                                if (float.IsNaN(left) || float.IsNaN(top)
                                    || float.IsInfinity(left) || float.IsInfinity(top)
                                    || left > (float)screenWidth || left + width < 0f
                                    || top > (float)screenHeight || top + height < 0f)
                                {
                                    continue;
                                }
                                bool inFov = false;
                                if (espFovRadius > 0f)
                                {
                                    float dxF = left + width * 0.5f - (float)screenWidth * 0.5f;
                                    float dyF = top + height * 0.5f - (float)screenHeight * 0.5f;
                                    inFov = (dxF * dxF + dyF * dyF) <= (espFovRadius * espFovRadius);
                                }
                                Color lineEspColor = (inFov || dying) ? Color.red : _cl;
                                Color boxEspColor = (inFov || dying) ? Color.red : _cb2;

                                if ((mask & EspBox) != 0)
                                {
                                    GUI.color = boxEspColor;
                                    GUI.DrawTexture(new Rect(left, top, width, thickness), pixel);
                                    GUI.DrawTexture(new Rect(
                                        left, top + height - thickness, width, thickness), pixel);
                                    GUI.DrawTexture(new Rect(left, top, thickness, height), pixel);
                                    GUI.DrawTexture(new Rect(
                                        left + width - thickness, top, thickness, height), pixel);
                                }

                                if ((mask & EspTracer) != 0)
                                {
                                    float startX = (float)screenWidth * 0.5f;
                                    float startY = 0f;
                                    float endX = left + width * 0.5f;
                                    float endY = top;
                                    float tracerX = endX - startX;
                                    float tracerY = endY - startY;
                                    float tracerLength = Mathf.Sqrt(
                                        tracerX * tracerX + tracerY * tracerY);
                                    float tracerAngle = Mathf.Atan2(
                                        tracerY, tracerX) * 57.29578f;
                                    GUI.matrix = Matrix4x4.TRS(
                                        new Vector3(startX, startY, 0f),
                                        Quaternion.Euler(0f, 0f, tracerAngle),
                                        Vector3.one);
                                    GUI.color = lineEspColor;
                                    GUI.DrawTexture(new Rect(0f, -lineThick * 0.5f, tracerLength, lineThick), pixel);
                                    GUI.matrix = Matrix4x4.identity;
                                }

                                if ((mask & EspHealth) != 0)
                                {
                                    float healthRatio = maximumHealth > 0
                                        ? Mathf.Clamp01((float)health / (float)maximumHealth)
                                        : 0f;
                                    float healthX = left + width + 2f;
                                    GUI.color = new Color(0f, 0f, 0f, 0.9f);
                                    GUI.DrawTexture(new Rect(healthX, top, c_boxThick + 2f, height), pixel);
                                    GUI.color = dying
                                        ? new Color(1f, 0f, 0f, 1f)
                                        : (espOn ? _ch
                                            : (healthRatio < 0.3f
                                                ? new Color(1f, 0f, 0f, 1f)
                                                : (healthRatio <= 0.6f
                                                    ? new Color(1f, 1f, 0f, 1f)
                                                    : new Color(0f, 1f, 0f, 1f))));
                                    GUI.DrawTexture(new Rect(
                                        healthX + 1f,
                                        top + height - height * healthRatio,
                                        c_boxThick,
                                        height * healthRatio), pixel);
                                }

                                if ((mask & EspName) != 0)
                                {
                                    string nickname = player.NickName;
                                    bool isBot = string.IsNullOrEmpty(nickname);
                                    if (isBot) nickname = "Bot CheatiOSVip";
                                    else if (nickname.Length > 10) nickname = nickname.Substring(0, 10);
                                    string numStr = (enemyCount + 1).ToString();
                                    float badgeH = 14f * c_nameScale;
                                    float textScale = 0.65f * c_nameScale;
                                    float nameBadgeW = (isBot ? 130f : 90f) * c_nameScale;
                                    float numBadgeW = (numStr.Length == 1 ? 14f : 20f) * c_nameScale;
                                    float centerX = left + width * 0.5f + 8.5f;
                                    float badgeY = top - badgeH - 2f;
                                    float nameBadgeX = centerX - nameBadgeW * 0.5f;
                                    float numBadgeX = nameBadgeX - numBadgeW;
                                    GUI.skin.label.alignment = TextAnchor.MiddleCenter;
                                    // Number badge: green #00FF00 semi-transparent, red when dying
                                    GUI.color = dying ? new Color(0.7f, 0f, 0f, 0.55f) : new Color(0f, 1f, 0f, 0.55f);
                                    GUI.DrawTexture(new Rect(numBadgeX, badgeY, numBadgeW, badgeH), pixel);
                                    GUI.color = dying ? Color.white : new Color(1f, 1f, 0f, 1f);
                                    GUI.matrix = Matrix4x4.TRS(new Vector3(numBadgeX, badgeY, 0f), Quaternion.identity, new Vector3(textScale, textScale, 1f));
                                    GUI.Label(new Rect(0f, 0f, numBadgeW / textScale, badgeH / textScale), numStr);
                                    GUI.matrix = Matrix4x4.identity;
                                    // Name badge: black background semi-transparent, dark red when dying
                                    GUI.color = dying ? new Color(0.5f, 0f, 0f, 0.55f) : new Color(0f, 0f, 0f, 0.50f);
                                    GUI.DrawTexture(new Rect(nameBadgeX, badgeY, nameBadgeW, badgeH), pixel);
                                    GUI.color = Color.white;
                                    GUI.matrix = Matrix4x4.TRS(new Vector3(nameBadgeX, badgeY, 0f), Quaternion.identity, new Vector3(textScale, textScale, 1f));
                                    GUI.Label(new Rect(0f, 0f, nameBadgeW / textScale, badgeH / textScale), nickname);
                                    GUI.matrix = Matrix4x4.identity;
                                    GUI.skin.label.alignment = TextAnchor.UpperLeft;
                                }

                                if ((mask & EspDistance) != 0)
                                {
                                    int distVal = (int)Mathf.Clamp(distance, 0f, 999f);
                                    string distStr = distVal.ToString() + "m";
                                    float dW = (float)distStr.Length * 9f;
                                    float dX = left + width * 0.5f - dW * 0.5f;
                                    float dY = top + height + 4f;
                                    GUI.color = _cd;
                                    GUI.Label(new Rect(dX, dY, dW, 18f), distStr);
                                }

                                if ((state & EspSkeleton) != 0)
                                {
                                    Transform skelNeck  = player.NeckBone;
                                    Transform skelArmL  = player.ArmBoneLeft;
                                    Transform skelArmR  = player.ArmBoneRight;
                                    Transform skelHandL = player.HandBoneLeft;
                                    Transform skelHandR = player.HandBoneRight;
                                    Transform skelFootL = player.FootBoneLeft;
                                    Transform skelFootR = player.FootBoneRight;
                                    // _sLegL/_sLegR already fetched above for box (_hipWorld reused)
                                    Vector3 spHead  = camera.WorldToScreenPoint(head.position);
                                    Vector3 spNeck  = skelNeck  != null ? camera.WorldToScreenPoint(skelNeck.position)  : new Vector3(0f, 0f, -1f);
                                    Vector3 spArmL  = skelArmL  != null ? camera.WorldToScreenPoint(skelArmL.position)  : new Vector3(0f, 0f, -1f);
                                    Vector3 spArmR  = skelArmR  != null ? camera.WorldToScreenPoint(skelArmR.position)  : new Vector3(0f, 0f, -1f);
                                    Vector3 spHandL = skelHandL != null ? camera.WorldToScreenPoint(skelHandL.position) : new Vector3(0f, 0f, -1f);
                                    Vector3 spHandR = skelHandR != null ? camera.WorldToScreenPoint(skelHandR.position) : new Vector3(0f, 0f, -1f);
                                    Vector3 spFootL = skelFootL != null ? camera.WorldToScreenPoint(skelFootL.position) : new Vector3(0f, 0f, -1f);
                                    Vector3 spFootR = skelFootR != null ? camera.WorldToScreenPoint(skelFootR.position) : new Vector3(0f, 0f, -1f);
                                    Vector3 spHip   = camera.WorldToScreenPoint(_hipWorld);
                                    // Interpolated joints (screen space, matching Theos): elbow=midpoint(shoulder,hand); knee=45% hipâ†’foot
                                    Vector3 spElbowL = (spArmL.z > 0f && spHandL.z > 0f) ? new Vector3(spArmL.x + (spHandL.x - spArmL.x) * 0.5f, spArmL.y + (spHandL.y - spArmL.y) * 0.5f, 1f) : new Vector3(0f, 0f, -1f);
                                    Vector3 spElbowR = (spArmR.z > 0f && spHandR.z > 0f) ? new Vector3(spArmR.x + (spHandR.x - spArmR.x) * 0.5f, spArmR.y + (spHandR.y - spArmR.y) * 0.5f, 1f) : new Vector3(0f, 0f, -1f);
                                    Vector3 spKneeL  = (spHip.z  > 0f && spFootL.z > 0f) ? new Vector3(spHip.x + (spFootL.x - spHip.x) * 0.45f, spHip.y + (spFootL.y - spHip.y) * 0.45f, 1f) : new Vector3(0f, 0f, -1f);
                                    Vector3 spKneeR  = (spHip.z  > 0f && spFootR.z > 0f) ? new Vector3(spHip.x + (spFootR.x - spHip.x) * 0.45f, spHip.y + (spFootR.y - spHip.y) * 0.45f, 1f) : new Vector3(0f, 0f, -1f);
                                    GUI.color = dying ? Color.red : _csk;
                                    // Headâ†’Neck
                                    if (spHead.z > 0f && spNeck.z > 0f) { float _x1 = spHead.x, _y1 = (float)screenHeight - spHead.y, _x2 = spNeck.x, _y2 = (float)screenHeight - spNeck.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    // Neckâ†’ArmLâ†’ElbowLâ†’HandL
                                    if (spNeck.z > 0f && spArmL.z > 0f) { float _x1 = spNeck.x, _y1 = (float)screenHeight - spNeck.y, _x2 = spArmL.x, _y2 = (float)screenHeight - spArmL.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spArmL.z > 0f && spElbowL.z > 0f) { float _x1 = spArmL.x, _y1 = (float)screenHeight - spArmL.y, _x2 = spElbowL.x, _y2 = (float)screenHeight - spElbowL.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spElbowL.z > 0f && spHandL.z > 0f) { float _x1 = spElbowL.x, _y1 = (float)screenHeight - spElbowL.y, _x2 = spHandL.x, _y2 = (float)screenHeight - spHandL.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    // Neckâ†’ArmRâ†’ElbowRâ†’HandR
                                    if (spNeck.z > 0f && spArmR.z > 0f) { float _x1 = spNeck.x, _y1 = (float)screenHeight - spNeck.y, _x2 = spArmR.x, _y2 = (float)screenHeight - spArmR.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spArmR.z > 0f && spElbowR.z > 0f) { float _x1 = spArmR.x, _y1 = (float)screenHeight - spArmR.y, _x2 = spElbowR.x, _y2 = (float)screenHeight - spElbowR.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spElbowR.z > 0f && spHandR.z > 0f) { float _x1 = spElbowR.x, _y1 = (float)screenHeight - spElbowR.y, _x2 = spHandR.x, _y2 = (float)screenHeight - spHandR.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    // Neckâ†’Hip (spine)
                                    if (spNeck.z > 0f && spHip.z > 0f) { float _x1 = spNeck.x, _y1 = (float)screenHeight - spNeck.y, _x2 = spHip.x, _y2 = (float)screenHeight - spHip.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    // Hipâ†’KneeLâ†’FootL
                                    if (spHip.z > 0f && spKneeL.z > 0f) { float _x1 = spHip.x, _y1 = (float)screenHeight - spHip.y, _x2 = spKneeL.x, _y2 = (float)screenHeight - spKneeL.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spKneeL.z > 0f && spFootL.z > 0f) { float _x1 = spKneeL.x, _y1 = (float)screenHeight - spKneeL.y, _x2 = spFootL.x, _y2 = (float)screenHeight - spFootL.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    // Hipâ†’KneeRâ†’FootR
                                    if (spHip.z > 0f && spKneeR.z > 0f) { float _x1 = spHip.x, _y1 = (float)screenHeight - spHip.y, _x2 = spKneeR.x, _y2 = (float)screenHeight - spKneeR.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                    if (spKneeR.z > 0f && spFootR.z > 0f) { float _x1 = spKneeR.x, _y1 = (float)screenHeight - spKneeR.y, _x2 = spFootR.x, _y2 = (float)screenHeight - spFootR.y, _dx = _x2 - _x1, _dy = _y2 - _y1, _len = Mathf.Sqrt(_dx * _dx + _dy * _dy); if (_len >= 0.5f) { GUI.matrix = Matrix4x4.TRS(new Vector3(_x1, _y1, 0f), Quaternion.Euler(0f, 0f, Mathf.Atan2(_dy, _dx) * 57.29578f), Vector3.one); GUI.DrawTexture(new Rect(0f, -_sh, _len, c_skelThick), pixel); GUI.matrix = Matrix4x4.identity; } }
                                }
                                enemyCount++;
                                }
                                catch (Exception)
                                {
                                    // A recycled entity is skipped without aborting the frame.
                                }
                            }

                            if (enemyCount == 0)
                            {
                                float _lastNeg = PlayerPrefs.GetFloat("esp_neg", 0f);
                                if (now - _lastNeg > 20f)
                                {
                                    PlayerPrefs.SetFloat("esp_neg", now);
                                    System.GC.Collect();
                                    System.GC.Collect();
                                }
                            }

                            // Draw enemy counter using GUI.Label - gated by EspCount bit
                            if (showEspCount)
                            {
                                string countStr = totalEnemyCount > 0 ? "CheatiOSVip: " + totalEnemyCount.ToString() : "CheatiOSVip: No Enemy";
                                float cW = (float)countStr.Length * 8.5f;
                                float cScale = 3.0f;
                                float cX = (float)screenWidth * 0.5f - cW * cScale * 0.5f + 30f;
                                float cY = 55f;
                                GUI.color = totalEnemyCount > 0 ? _cc2 : new Color(0f, 1f, 0f, 1f);
                                for (int _bi = -1; _bi <= 1; _bi++)
                                {
                                    GUI.matrix = Matrix4x4.TRS(new Vector3(cX + _bi * 0.7f, cY, 0f), Quaternion.identity, new Vector3(cScale, cScale, 1f));
                                    GUI.Label(new Rect(0f, 0f, cW, 20f), countStr);
                                }
                                GUI.matrix = Matrix4x4.identity;
                                GUI.color = Color.white;
                            }
                        }
                    }
                }
            }
            catch (Exception)
            {
                // A transient Unity object is skipped for this event.
            }

            try
            {
                float encodedAuxState = self.{{SCENE_STATE_FIELD}}.y;
                if (encodedAuxState <= -AuxStateMarker)
                {
                    int packedAuxState = (int)(-encodedAuxState - AuxStateMarker);
                    int auxState = packedAuxState & AuxMask;
                    Player _lp = GameFacade.CurrentLocalPlayer();
                    if (_lp != null && _lp.gameObject != null && _lp.gameObject.activeInHierarchy)
                    {
                        float _dt = Time.deltaTime;
                        PlayerAttributes attributes = _lp.Attributes;
                        if (attributes != null)
                        {
                            bool speedRunning = (auxState & AuxSpeedRunning) != 0;
                            bool speedRunningApplied = (auxState & AuxSpeedRunningApplied) != 0;
                            if (speedRunning)
                            {
                                attributes.SetSpecialRunSpeedScaleByKeyAndValue(
                                    PlayerAttributes.{{SPEED_TYPE}}.BuffSystem,
                                    SpeedRunningKey, 3f);
                                auxState |= AuxSpeedRunningApplied;
                            }
                            else if (speedRunningApplied)
                            {
                                attributes.RemoveSpecialRunSpeedScaleByKey(
                                    PlayerAttributes.{{SPEED_TYPE}}.BuffSystem,
                                    SpeedRunningKey);
                                auxState &= ~AuxSpeedRunningApplied;
                            }

                            if ((auxState & AuxFakeDamage) != 0)
                            {
                                attributes.BuffWeaponDamageScale = 10000.0f;
                                attributes.DamageAdditionScale   = 10000.0f;
                                attributes.ExecuteDamageScale    = 10000.0f;
                            }
                            else if (attributes.BuffWeaponDamageScale > 10.0f)
                            {
                                attributes.BuffWeaponDamageScale = 0f;
                                attributes.DamageAdditionScale   = 0f;
                                attributes.ExecuteDamageScale    = 0f;
                            }
                        }

                        {
                            int fullAux = packedAuxState;
                            bool isWide = (fullAux & AuxWideCamera) != 0;
                            if (isWide)
                            {
                                int wcRaw = (fullAux >> AuxWideCamFovShift) & 0x3F;
                                float wFov = wcRaw > 0 ? 60f + (float)wcRaw : 88f;
                                CameraControllerManager camMgr =
                                    GameFacade.CurrentCameraControllerManager();
                                if (camMgr != null)
                                    camMgr.SetFov(wFov);
                            }
                        }

                        {
                            int fullAux = packedAuxState;
                            bool fastHealOn = (fullAux & AuxFastHeal) != 0;
                            PlayerAttributes healAttrs = _lp.Attributes;
                            if (healAttrs != null)
                            {
                                if (fastHealOn)
                                {
                                    healAttrs.EatSpeedScale = 10.0f;
                                    healAttrs.FSModeUseMedikitFasterRate = 10.0f;
                                    healAttrs.BeHealingIncreaseRatio = 5.0f;
                                }
                                else if (healAttrs.EatSpeedScale > 1.5f)
                                {
                                    healAttrs.EatSpeedScale = 1.0f;
                                    healAttrs.FSModeUseMedikitFasterRate = 0.0f;
                                    healAttrs.BeHealingIncreaseRatio = 0.0f;
                                }
                            }
                        }

                        {
                            int fullAux = packedAuxState;
                            bool fastFireOn = (fullAux & AuxFastFire) != 0;
                            PlayerAttributes fireAttrs = _lp.Attributes;
                            if (fireAttrs != null)
                            {
                                if (fastFireOn)
                                {
                                    fireAttrs.FireIntervalScale = 0.5f;
                                }
                                else if (fireAttrs.FireIntervalScale < 0.9f)
                                {
                                    fireAttrs.FireIntervalScale = 1.0f;
                                }
                            }
                        }

                        {
                            int r8 = (int)PlayerPrefs.GetFloat("esp_r8", 0f);
                            PlayerAttributes rAttrs = _lp.Attributes;
                            if (rAttrs != null)
                            {
                                bool fastReviveOn = (r8 & R8FastRevive) != 0;
                                if (fastReviveOn) { rAttrs.RescureRate = 5.0f; }
                                else if (rAttrs.RescureRate > 2.0f) { rAttrs.RescureRate = 1.0f; }
                                bool skillCDOn = (r8 & R8SkillCD) != 0;
                                rAttrs.ActiveSkillCdReduction = skillCDOn ? 0.9f : 0f;
                                rAttrs.PetSkillCDReduction = skillCDOn ? 0.9f : 0f;
                            }
                        }

                        {
                            if ((state & AimSystemEnabled) != 0 && (state & AimEnabled) == 0
                                && Input.touchCount >= 2)
                            {
                                Camera _cam = Camera.main;
                                {{MATCH_TYPE}} _match = GameFacade.CurrentMatch();
                                IList _pl = _match == null ? null : _match.{{MATCH_PLAYERS_METHOD}}();
                                if (_cam != null && _pl != null)
                                {
                                    int _mode = (state & AimModeMask) >> AimModeShift;
                                    int _fovRaw = (packedAuxState >> AuxFovRadiusShift) & 0xFF;
                                    float _fovR = _fovRaw >= 10 ? (float)_fovRaw * 2f : 200f;
                                    float _bestSc = _fovR * _fovR;
                                    Player _bt = null; Collider _bc = null; Vector3 _bp = Vector3.zero;
                                    int _pcnt = _pl.Count; if (_pcnt > 64) _pcnt = 64;
                                    for (int _i = 0; _i < _pcnt; _i++)
                                    {
                                        try
                                        {
                                            Player _c = _pl[_i] as Player;
                                            if (_c == null || _c.gameObject == null
                                                || !_c.gameObject.activeInHierarchy
                                                || _c.IsLocalPlayer() || _c.CurHP <= 0
                                                || _c.IsLocalTeammate(false)
                                                || _c.IsLocalTeammate(true)
                                                || ((_c.IsDieing || _c.IsKnockedDownBleed) && (state & AimSkipDowned) != 0)) continue;
                                            Transform _cr = _c.RootTransform;
                                            if (_cr == null) continue;
                                            Vector3 _tp; Collider _tc = null;
                                            if (_mode == 1)
                                            {
                                                Transform _h = _c.GetHeadTF();
                                                if (_h == null) continue;
                                                _tp = _h.position;
                                                _tc = _c.HeadCollider;
                                                if (_tc == null) _tc = (Collider)_h.GetComponent(typeof(Collider));
                                            }
                                            else
                                            {
                                                _tp = _cr.position + new Vector3(0f, 0.9f, 0f);
                                                _tc = (Collider)_cr.GetComponent("CapsuleCollider");
                                                if (_tc == null) _tc = _c.HeadCollider;
                                            }
                                            if (_tc == null) continue;
                                            Vector3 _sv = _cam.WorldToScreenPoint(_tp);
                                            if (_sv.z <= 1f || float.IsNaN(_sv.x) || float.IsNaN(_sv.y)
                                                || float.IsInfinity(_sv.x) || float.IsInfinity(_sv.y)) continue;
                                            float _dx = _sv.x - (float)Screen.width * 0.5f;
                                            float _dy = _sv.y - (float)Screen.height * 0.5f;
                                            float _sc = _dx * _dx + _dy * _dy;
                                            if (float.IsNaN(_sc) || float.IsInfinity(_sc) || _sc >= _bestSc) continue;
                                            _bestSc = _sc; _bt = _c; _bc = _tc; _bp = _tp;
                                        }
                                        catch (Exception) { }
                                    }
                                    if (_bt != null && _bc != null)
                                    {
                                        try
                                        {
                                            _bt.EspLockedAimingCollider = _bc;
                                            Vector3 _dir = _bp - _lp.AimStartPostion;
                                            float _dlen = _dir.sqrMagnitude;
                                            if (_dlen > 0.0001f && !float.IsNaN(_dlen) && !float.IsInfinity(_dlen))
                                            {
                                                Quaternion _tgt = Quaternion.LookRotation(_dir);
                                                Quaternion _cur = _lp.GetAimRotation();
                                                float _fd = _dt > 0f && _dt < 0.1f ? _dt : 0.016f;
                                                float _bl = 1f - Mathf.Exp(-64f * _fd);
                                                _bl = Mathf.Clamp01(_bl);
                                                _lp.SetAimRotation(Quaternion.Slerp(_cur, _tgt, _bl), false);
                                            }
                                        }
                                        catch (Exception) { }
                                    }
                                }
                            }
                        }

                        if ((auxState & AuxFastParachute) != 0)
                        {
                            bool skySurfing = _lp.IsSkySurfing;
                            bool skyDiving = _lp.IsSkyDiving;
                            bool parachuting = _lp.IsParachuting;
                            if (skySurfing)
                            {
                                _lp.RequestSkyDiving();
                            }
                            else if (skyDiving || parachuting)
                            {
                                CharacterController controller = _lp.CharacterController;
                                if (controller != null && controller.enabled)
                                {
                                    RaycastHit groundHit;
                                    Vector3 origin = controller.transform.position;
                                    bool foundGround = Physics.Raycast(
                                        origin,
                                        new Vector3(0f, -1f, 0f),
                                        out groundHit,
                                        2048f,
                                        -5,
                                        QueryTriggerInteraction.Ignore);
                                    if (foundGround)
                                    {
                                        bool landed = controller.isGrounded;
                                        float groundDistance = groundHit.distance;
                                        if (!landed && groundDistance > 0f)
                                        {
                                            float contactPadding = controller.skinWidth;
                                            if (contactPadding < 0.05f)
                                            {
                                                contactPadding = 0.05f;
                                            }
                                            float moveDistance = groundDistance + contactPadding;
                                            float frameStep = _dt * 768f;
                                            if (frameStep < 0.5f)
                                            {
                                                frameStep = 0.5f;
                                            }
                                            else if (frameStep > 32f)
                                            {
                                                frameStep = 32f;
                                            }
                                            if (moveDistance > frameStep)
                                            {
                                                moveDistance = frameStep;
                                            }
                                            CollisionFlags collision =
                                                controller.Move(new Vector3(0f, -moveDistance, 0f));
                                            landed = (collision & CollisionFlags.Below) != 0
                                                || controller.isGrounded;
                                        }
                                        if (landed)
                                        {
                                            _lp.StopParachuting(true);
                                            _lp.OnLandFinsish();
                                        }
                                    }
                                }
                            }
                        }

                        packedAuxState = (packedAuxState & ~AuxMask) | (auxState & AuxMask);
                        self.{{SCENE_STATE_FIELD}} = new Vector2(
                            self.{{SCENE_STATE_FIELD}}.x,
                            -AuxStateMarker - (float)packedAuxState);
                    }
                }
            }
            catch (Exception) { }

            // Ghost floating button (draw after ESP so it stays on top)
            try
            {
                Vector2 _gPtr = Vector2.zero;
                bool _gDown = false, _gDrag = false, _gUp = false;
                if (Input.touchCount > 0)
                {
                    Touch _t = Input.GetTouch(0);
                    _gPtr = new Vector2(_t.position.x, (float)screenHeight - _t.position.y);
                    _gDown = _t.phase == TouchPhase.Began;
                    _gDrag = _t.phase == TouchPhase.Moved || _t.phase == TouchPhase.Stationary;
                    _gUp   = _t.phase == TouchPhase.Ended || _t.phase == TouchPhase.Canceled;
                }
                GhostFeature.DrawFloatingButton(Texture2D.whiteTexture, _gPtr, _gDown, _gDrag, _gUp, screenWidth, screenHeight);
            }
            catch (Exception) { }

            GUI.matrix = savedMatrix;
            GUI.color = savedColor;
        }

        public static {{AIM_INFO_TYPE}} SilentAim(Player self)
        {
            if (self == null)
            {
                return null;
            }
            {{AIM_INFO_TYPE}} info = self.{{PLAYER_AIM_INFO_FIELD}};
            if (info == null)
            {
                return info;
            }
            try
            {
                GameObject driver = GameObject.Find("__esp_driver");
            SceneEditBoxSelectTool menu = driver == null
                ? null
                : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.{{SCENE_STATE_FIELD}}.x;

            // FakeDamage: works independently of SilentAim toggle
            float fdEnc = menu == null ? 0f : menu.{{SCENE_STATE_FIELD}}.y;
            if (fdEnc <= -AuxStateMarker)
            {
                int fdAux = (int)(-fdEnc - AuxStateMarker) & AuxMask;
                PlayerAttributes fdAttrs = self.Attributes;
                if (fdAttrs != null)
                {
                    if ((fdAux & AuxFakeDamage) != 0)
                    {
                        fdAttrs.BuffWeaponDamageScale = 10000.0f;
                        fdAttrs.DamageAdditionScale   = 10000.0f;
                        fdAttrs.ExecuteDamageScale    = 10000.0f;
                    }
                    else if (fdAttrs.BuffWeaponDamageScale > 10.0f)
                    {
                        fdAttrs.BuffWeaponDamageScale = 0f;
                        fdAttrs.DamageAdditionScale   = 0f;
                        fdAttrs.ExecuteDamageScale    = 0f;
                    }
                }
            }

            bool silentAimOn = (state & AimEnabled) != 0;
            bool aimFovOn    = (state & AimSystemEnabled) != 0;
            if (!silentAimOn && !aimFovOn)
            {
                return info;
            }

            // Read FOV values from full aux bits (no AuxMask cap)
            int silentFovPx  = 0;
            int aimFovPixels = 0;
            if (fdEnc <= -AuxStateMarker)
            {
                int fullAux  = (int)(-fdEnc - AuxStateMarker);
                silentFovPx  = ((fullAux >> AuxSilentFovShift) & 0xFF) * 2;
                aimFovPixels = ((fullAux >> AuxFovRadiusShift) & 0xFF) * 2;
            }

            bool aimAtHead;
            int fovFilterPx;
            if (silentAimOn)
            {
                aimAtHead   = true;
                fovFilterPx = silentFovPx;
            }
            else
            {
                int aimModeFov  = (state & AimModeMask) >> AimModeShift;
                int headRateFov = ((state & HeadRateMask) >> HeadRateShift) * 25;
                aimAtHead   = aimModeFov == 1
                    || (aimModeFov == 2 && UnityEngine.Random.Range(0, 100) < headRateFov);
                fovFilterPx = aimFovPixels;
            }

            {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
            IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
            Camera camera = Camera.main;
            if (players == null || camera == null)
            {
                return info;
            }

            Vector3 aimStart = self.AimStartPostion;
            float bestScore = float.MaxValue;
            Collider bestCollider = null;
            Vector3 bestPosition = Vector3.zero;

            for (int index = 0; index < players.Count; index++)
            {
                Player candidate = players[index] as Player;
                GameObject candidateObject = candidate == null ? null : candidate.gameObject;
                if (candidateObject == null || !candidateObject.activeInHierarchy
                    || candidate.IsLocalPlayer()
                    || candidate.CurHP <= 0
                    || candidate.IsLocalTeammate(false)
                    || candidate.IsLocalTeammate(true)
                    || ((candidate.IsDieing || candidate.IsKnockedDownBleed) && (state & AimSkipDowned) != 0))
                {
                    continue;
                }

                Transform root = candidate.RootTransform;
                Transform head = candidate.GetHeadTF();
                Collider headCollider = candidate.HeadCollider;
                if (root == null)
                {
                    continue;
                }

                Vector3 hitPosition;
                Collider hitCollider;
                if (aimAtHead)
                {
                    if (head == null || headCollider == null)
                    {
                        continue;
                    }
                    hitPosition = head.position;
                    hitCollider = headCollider;
                }
                else
                {
                    hitPosition = root.position + new Vector3(0f, 0.9f, 0f);
                    hitCollider = (Collider)root.GetComponent("CapsuleCollider");
                    if (hitCollider == null)
                    {
                        if (head == null || headCollider == null)
                        {
                            continue;
                        }
                        hitCollider = headCollider;
                    }
                }

                if (Vector3.Distance(hitPosition, aimStart) > 150f)
                {
                    continue;
                }
                Vector3 screen = camera.WorldToScreenPoint(hitPosition);
                if (screen.z <= 1f
                    || float.IsNaN(screen.x) || float.IsNaN(screen.y)
                    || float.IsNaN(screen.z) || float.IsInfinity(screen.x)
                    || float.IsInfinity(screen.y) || float.IsInfinity(screen.z))
                {
                    continue;
                }
                float dx = screen.x - (float)Screen.width * 0.5f;
                float dy = screen.y - (float)Screen.height * 0.5f;
                float score = dx * dx + dy * dy;
                if (float.IsNaN(score) || float.IsInfinity(score)
                    || score >= bestScore)
                {
                    continue;
                }
                if (fovFilterPx > 0 && score > (float)(fovFilterPx * fovFilterPx))
                {
                    continue;
                }

                bestScore = score;
                bestCollider = hitCollider;
                bestPosition = hitPosition;
            }

            if (bestCollider != null)
            {
                if (silentAimOn)
                {
                    // Silent Aim: snap bullet direction instantly
                    Vector3 rayDirection = Vector3.Normalize(bestPosition - aimStart);
                    info.{{AIM_GAME_OBJECT_FIELD}} = bestCollider.gameObject;
                    info.{{AIM_COLLIDER_FIELD}} = bestCollider;
                    info.{{AIM_HIT_POSITION_FIELD}} = bestPosition;
                    info.{{AIM_TRACE_POSITION_FIELD}} = bestPosition;
                    info.{{AIM_DIRECTION_FIELD}} = rayDirection;
                    info.{{AIM_ORIGIN_FIELD}} = aimStart;
                    info.{{AIM_SECONDARY_ORIGIN_FIELD}} = aimStart;
                    info.{{AIM_HIT_TYPE_FIELD}} = ({{AIM_HIT_TYPE}})1;
                    info.{{AIM_FLAG_A_FIELD}} = false;
                    info.{{AIM_FLAG_B_FIELD}} = false;
                    info.{{AIM_SHORT_FIELD}} = (short)0;
                }
                else
                {
                    // Aim FOV: game's built-in aim assist toward locked collider
                    self.EspLockedAimingCollider = bestCollider;
                }
            }
                return info;
            }
            catch (Exception)
            {
                return info;
            }
        }

        public static bool AimSystem(Player self)
        {
            if (self == null)
            {
                return false;
            }
            bool original = false;
            try
            {
                original = self.EspBaseIsMovableEntity();
                GameObject driver = GameObject.Find("__esp_driver");
            SceneEditBoxSelectTool menu = driver == null
                ? null
                : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.{{SCENE_STATE_FIELD}}.x;
            if ((state & AimSystemEnabled) == 0 || (state & AimEnabled) != 0
                || self.gameObject == null || !self.gameObject.activeInHierarchy
                || self.IsLocalPlayer() || self.CurHP <= 0
                || self.IsLocalTeammate(false) || self.IsLocalTeammate(true)
                || ((self.IsDieing || self.IsKnockedDownBleed) && (state & AimSkipDowned) != 0))
            {
                return original;
            }

            int aimModeFov = (state & AimModeMask) >> AimModeShift;
            int headRateFov = ((state & HeadRateMask) >> HeadRateShift) * 25;
            bool fovAimAtHead = aimModeFov == 1
                || (aimModeFov == 2 && UnityEngine.Random.Range(0, 100) < headRateFov);
            Collider targetCollider = null;
            if (fovAimAtHead)
            {
                targetCollider = self.HeadCollider;
            }
            else
            {
                Transform neck = self.NeckBone;
                IList fireColliders = self.FireColliders;
                float nearestDistance = 10000f;
                if (neck != null && fireColliders != null)
                {
                    for (int index = 0; index < fireColliders.Count; index++)
                    {
                        Collider candidateCollider = fireColliders[index] as Collider;
                        if (candidateCollider == null)
                        {
                            continue;
                        }

                        float distance = Vector3.Distance(
                            candidateCollider.transform.position, neck.position);
                        if (distance < nearestDistance)
                        {
                            nearestDistance = distance;
                            targetCollider = candidateCollider;
                        }
                    }
                }

                if (targetCollider == null && neck != null)
                {
                    targetCollider = (Collider)neck.GetComponent(typeof(Collider));
                }
                if (targetCollider == null)
                {
                    Transform root = self.RootTransform;
                    targetCollider = root == null
                        ? null
                        : (Collider)root.GetComponent("CapsuleCollider");
                }
                if (targetCollider == null)
                {
                    targetCollider = self.HeadCollider;
                }
            }

            if (targetCollider == null)
            {
                return original;
            }

            float fovEnc = menu == null ? 0f : menu.{{SCENE_STATE_FIELD}}.y;
            int fovPackedAim = fovEnc <= -AuxStateMarker
                ? (int)(-fovEnc - AuxStateMarker) : 0;
            float fovRadiusAim = (float)((fovPackedAim >> AuxFovRadiusShift) & 0xFF) * 2f;
            if (fovRadiusAim > 0f)
            {
                Camera camAim = Camera.main;
                if (camAim != null)
                {
                    Vector3 screenPosAim = camAim.WorldToScreenPoint(
                        targetCollider.transform.position);
                    if (screenPosAim.z > 0f)
                    {
                        float dxAim = screenPosAim.x - (float)Screen.width * 0.5f;
                        float dyAim = screenPosAim.y - (float)Screen.height * 0.5f;
                        if (dxAim * dxAim + dyAim * dyAim > fovRadiusAim * fovRadiusAim)
                        {
                            return original;
                        }
                    }
                }
            }

            self.EspLockedAimingCollider = targetCollider;
                return original;
            }
            catch (Exception)
            {
                return original;
            }
        }

        public static float ScatterRate(PlayerAttributes self)
        {
            if (self == null)
            {
                return 0f;
            }
            try
            {
                GameObject driver = GameObject.Find("__esp_driver");
            SceneEditBoxSelectTool menu = driver == null
                ? null
                : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.{{SCENE_STATE_FIELD}}.x;
            if ((state & NoRecoil) != 0)
            {
                return 0f;
            }
                return 1f;
            }
            catch (Exception)
            {
                return 1f;
            }
        }
    }
}
