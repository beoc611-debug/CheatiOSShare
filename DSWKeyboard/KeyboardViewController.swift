import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<DSWToolsView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let toolsView = DSWToolsView(controller: self)
        let host = UIHostingController(rootView: toolsView)
        hostingController = host
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
}
