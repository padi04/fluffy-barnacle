import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.isAccessibilityElement = true
        skView.accessibilityLabel = "Pong Game"
        skView.accessibilityHint = "Tap to start. Drag in the lower half to move your paddle."
        skView.accessibilityTraits = .allowsDirectInteraction
        view.addSubview(skView)

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
