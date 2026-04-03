import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Constants

    private enum Category: UInt32 {
        case ball   = 0x1
        case paddle = 0x2
        case wall   = 0x4
        case goal   = 0x8
    }

    private let paddleWidth: CGFloat = 100
    private let paddleHeight: CGFloat = 16
    private let paddleOffset: CGFloat = 60
    private let ballRadius: CGFloat = 10
    private let ballSpeed: CGFloat = 400
    private let aiSpeed: CGFloat = 3.5

    // MARK: - Nodes

    private var ball: SKShapeNode!
    private var playerPaddle: SKShapeNode!
    private var aiPaddle: SKShapeNode!
    private var playerScoreLabel: SKLabelNode!
    private var aiScoreLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!

    // MARK: - State

    private var playerScore = 0
    private var aiScore = 0
    private var isPlaying = false
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        createWalls()
        createGoalZones()
        createPaddles()
        createBall()
        createScoreLabels()
        createMessageLabel()

        showMessage("Tap to Start")
    }

    private func createWalls() {
        let left = SKNode()
        left.position = CGPoint(x: 0, y: size.height / 2)
        left.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 1, height: size.height))
        left.physicsBody?.isDynamic = false
        left.physicsBody?.categoryBitMask = Category.wall.rawValue
        left.physicsBody?.friction = 0
        left.physicsBody?.restitution = 1
        addChild(left)

        let right = SKNode()
        right.position = CGPoint(x: size.width, y: size.height / 2)
        right.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 1, height: size.height))
        right.physicsBody?.isDynamic = false
        right.physicsBody?.categoryBitMask = Category.wall.rawValue
        right.physicsBody?.friction = 0
        right.physicsBody?.restitution = 1
        addChild(right)
    }

    private func createGoalZones() {
        // Bottom goal (AI scores)
        let bottomGoal = SKNode()
        bottomGoal.name = "bottomGoal"
        bottomGoal.position = CGPoint(x: size.width / 2, y: -10)
        bottomGoal.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 1))
        bottomGoal.physicsBody?.isDynamic = false
        bottomGoal.physicsBody?.categoryBitMask = Category.goal.rawValue
        bottomGoal.physicsBody?.contactTestBitMask = Category.ball.rawValue
        bottomGoal.physicsBody?.collisionBitMask = 0
        addChild(bottomGoal)

        // Top goal (Player scores)
        let topGoal = SKNode()
        topGoal.name = "topGoal"
        topGoal.position = CGPoint(x: size.width / 2, y: size.height + 10)
        topGoal.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 1))
        topGoal.physicsBody?.isDynamic = false
        topGoal.physicsBody?.categoryBitMask = Category.goal.rawValue
        topGoal.physicsBody?.contactTestBitMask = Category.ball.rawValue
        topGoal.physicsBody?.collisionBitMask = 0
        addChild(topGoal)
    }

    private func createPaddles() {
        playerPaddle = makePaddle()
        playerPaddle.position = CGPoint(x: size.width / 2, y: paddleOffset)
        addChild(playerPaddle)

        aiPaddle = makePaddle()
        aiPaddle.position = CGPoint(x: size.width / 2, y: size.height - paddleOffset)
        addChild(aiPaddle)
    }

    private func makePaddle() -> SKShapeNode {
        let paddle = SKShapeNode(rectOf: CGSize(width: paddleWidth, height: paddleHeight), cornerRadius: 8)
        paddle.fillColor = .white
        paddle.strokeColor = .clear
        paddle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: paddleWidth, height: paddleHeight))
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = Category.paddle.rawValue
        paddle.physicsBody?.friction = 0
        paddle.physicsBody?.restitution = 1
        return paddle
    }

    private func createBall() {
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = .white
        ball.strokeColor = .clear
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)

        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.categoryBitMask = Category.ball.rawValue
        ball.physicsBody?.contactTestBitMask = Category.goal.rawValue
        ball.physicsBody?.collisionBitMask = Category.paddle.rawValue | Category.wall.rawValue
        ball.physicsBody?.friction = 0
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.angularDamping = 0
        ball.physicsBody?.allowsRotation = false
        addChild(ball)
    }

    private func createScoreLabels() {
        playerScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        playerScoreLabel.fontSize = 48
        playerScoreLabel.fontColor = .white
        playerScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60)
        playerScoreLabel.alpha = 0.3
        playerScoreLabel.text = "0"
        addChild(playerScoreLabel)

        aiScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        aiScoreLabel.fontSize = 48
        aiScoreLabel.fontColor = .white
        aiScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        aiScoreLabel.alpha = 0.3
        aiScoreLabel.text = "0"
        addChild(aiScoreLabel)

        // Center line
        let dashes = 30
        let dashHeight: CGFloat = 4
        let gap = size.height / CGFloat(dashes * 2)
        for i in 0..<dashes {
            let dash = SKShapeNode(rectOf: CGSize(width: 2, height: dashHeight))
            dash.fillColor = .white
            dash.strokeColor = .clear
            dash.alpha = 0.2
            dash.position = CGPoint(x: size.width / 2, y: gap + CGFloat(i) * gap * 2)
            addChild(dash)
        }
    }

    private func createMessageLabel() {
        messageLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        messageLabel.fontSize = 28
        messageLabel.fontColor = .white
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.isHidden = true
        addChild(messageLabel)
    }

    // MARK: - Game Flow

    private func showMessage(_ text: String) {
        messageLabel.text = text
        messageLabel.isHidden = false
    }

    private func launchBall() {
        isPlaying = true
        messageLabel.isHidden = true

        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ball.physicsBody?.velocity = .zero

        let angle = CGFloat.random(in: .pi / 6 ... .pi / 3) * (Bool.random() ? 1 : -1)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let dx = sin(angle) * ballSpeed
        let dy = cos(angle) * ballSpeed * direction

        ball.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
    }

    private func scored(byPlayer: Bool) {
        isPlaying = false
        ball.physicsBody?.velocity = .zero
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)

        if byPlayer {
            playerScore += 1
            playerScoreLabel.text = "\(playerScore)"
        } else {
            aiScore += 1
            aiScoreLabel.text = "\(aiScore)"
        }

        if playerScore >= 7 {
            showMessage("You Win! Tap to Restart")
            playerScore = 0
            aiScore = 0
            playerScoreLabel.text = "0"
            aiScoreLabel.text = "0"
        } else if aiScore >= 7 {
            showMessage("You Lose! Tap to Restart")
            playerScore = 0
            aiScore = 0
            playerScoreLabel.text = "0"
            aiScoreLabel.text = "0"
        } else {
            showMessage("Tap to Serve")
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isPlaying {
            launchBall()
            return
        }

        guard let touch = touches.first else { return }
        movePaddle(to: touch.location(in: self).x)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isPlaying else { return }
        movePaddle(to: touch.location(in: self).x)
    }

    private func movePaddle(to x: CGFloat) {
        playerPaddle.position.x = max(paddleWidth / 2, min(size.width - paddleWidth / 2, x))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / 60.0
        lastUpdateTime = currentTime

        guard isPlaying else { return }

        // AI tracks the ball with slight delay using real delta time
        let diff = ball.position.x - aiPaddle.position.x
        let newX = aiPaddle.position.x + diff * aiSpeed * CGFloat(dt) * 4
        aiPaddle.position.x = max(paddleWidth / 2, min(size.width - paddleWidth / 2, newX))

        // Normalize ball speed and prevent horizontal stalling
        guard var velocity = ball.physicsBody?.velocity else { return }
        let minVertical: CGFloat = ballSpeed * 0.3
        if abs(velocity.dy) < minVertical {
            velocity.dy = velocity.dy >= 0 ? minVertical : -minVertical
        }
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > 0 {
            let scale = ballSpeed / speed
            ball.physicsBody?.velocity = CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
        }
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPlaying else { return }

        let names = [contact.bodyA.node?.name, contact.bodyB.node?.name]
        if names.contains("topGoal") {
            scored(byPlayer: true)
        } else if names.contains("bottomGoal") {
            scored(byPlayer: false)
        }
    }
}
