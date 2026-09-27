# Script push code len GitHub va trigger build IPA
# Chay: Right-click -> Run with PowerShell

$token = Read-Host "Nhap GitHub token cua ban"
$repoUrl = "https://${token}@github.com/beoc611-debug/CheatiOSShare.git"

Set-Location $PSScriptRoot

# Kiem tra repo ton tai khong, neu chua thi tao
Write-Host "Kiem tra repo beoc611-debug/CheatiOSShare..."
$check = Invoke-RestMethod -Uri "https://api.github.com/repos/beoc611-debug/CheatiOSShare" `
    -Headers @{ Authorization = "token $token"; "User-Agent" = "curl" } `
    -ErrorAction SilentlyContinue

if (-not $check) {
    Write-Host "Repo chua ton tai, dang tao..."
    $body = @{ name = "CheatiOSShare"; private = $true; description = "CheatiOSShare iOS App" } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://api.github.com/user/repos" `
        -Method POST `
        -Headers @{ Authorization = "token $token"; "User-Agent" = "curl"; "Content-Type" = "application/json" } `
        -Body $body | Out-Null
    Write-Host "Da tao repo thanh cong."
    Start-Sleep -Seconds 2
} else {
    Write-Host "Repo da ton tai: $($check.html_url)"
}

# Cap nhat remote beoc voi token moi
git remote set-url beoc $repoUrl 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add beoc $repoUrl
}

# Stage tat ca file moi/sua
git add -A
git status

# Commit
$msg = "feat: add FreeFire ESP controls in home tab + GitHub Actions build workflow"
git commit -m $msg 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Khong co gi de commit (hoac da commit roi)"
}

# Push
Write-Host "Dang push len beoc611-debug/CheatiOSShare..."
git push beoc HEAD:master --force

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "PUSH THANH CONG!"
    Write-Host "Vao day de xem build: https://github.com/beoc611-debug/CheatiOSShare/actions"
    Write-Host "IPA se co trong tab Actions -> Build IPA -> Artifacts sau ~5-10 phut"
} else {
    Write-Host "Push that bai. Kiem tra lai token va quyen repo."
}

Read-Host "Nhan Enter de dong"
