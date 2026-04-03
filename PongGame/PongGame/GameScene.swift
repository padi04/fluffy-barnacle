import SpriteKit
import UIKit
import AVFoundation

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
    private let ballRadius: CGFloat = 10
    private let baseBallSpeed: CGFloat = 400
    private let maxBallSpeed: CGFloat = 650
    private let speedIncrement: CGFloat = 15
    private let aiSpeed: CGFloat = 3.5
    private let winScore = 7

    // MARK: - Nodes

    private var ball: SKShapeNode!
    private var playerPaddle: SKShapeNode!
    private var aiPaddle: SKShapeNode!
    private var playerScoreLabel: SKLabelNode!
    private var aiScoreLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!

    // MARK: - Haptics

    private let paddleHitFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let wallHitFeedback = UIImpactFeedbackGenerator(style: .light)
    private let goalFeedback = UINotificationFeedbackGenerator()

    // MARK: - Audio

    private var audioEngine: AVAudioEngine!
    private var paddleToneBuffer: AVAudioPCMBuffer!
    private var wallToneBuffer: AVAudioPCMBuffer!
    private var scoreToneBuffer: AVAudioPCMBuffer!
    private var winToneBuffer: AVAudioPCMBuffer!
    private var playerNode: AVAudioPlayerNode!

    // MARK: - State

    private var playerScore = 0
    private var aiScore = 0
    private var isPlaying = false
    private var lastUpdateTime: TimeInterval = 0
    private var currentBallSpeed: CGFloat = 400
    private var rallyCount = 0
    private var safeAreaBottom: CGFloat = 0
    private var safeAreaTop: CGFloat = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black

        let insets = view.safeAreaInsets
        safeAreaBottom = insets.bottom
        safeAreaTop = insets.top

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        createWalls()
        createGoalZones()
        createPaddles()
        createBall()
        createScoreLabels()
        createCenterLine()
        createMessageLabel()
        prepareHaptics()
        prepareAudio()
        observeAppLifecycle()

        showMessage("Tap to Start")
    }

    private func createWalls() {
        for xPos in [CGFloat(0), size.width] {
            let wall = SKNode()
            wall.name = "wall"
            wall.position = CGPoint(x: xPos, y: size.height / 2)
            wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 1, height: size.height))
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.categoryBitMask = Category.wall.rawValue
            wall.physicsBody?.contactTestBitMask = Category.ball.rawValue
            wall.physicsBody?.friction = 0
            wall.physicsBody?.restitution = 1
            addChild(wall)
        }
    }

    private func createGoalZones() {
        let bottomGoal = SKNode()
        bottomGoal.name = "bottomGoal"
        bottomGoal.position = CGPoint(x: size.width / 2, y: -10)
        bottomGoal.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 1))
        bottomGoal.physicsBody?.isDynamic = false
        bottomGoal.physicsBody?.categoryBitMask = Category.goal.rawValue
        bottomGoal.physicsBody?.contactTestBitMask = Category.ball.rawValue
        bottomGoal.physicsBody?.collisionBitMask = 0
        addChild(bottomGoal)

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
        let paddleOffset: CGFloat = 60

        playerPaddle = makePaddle()
        playerPaddle.name = "playerPaddle"
        playerPaddle.position = CGPoint(x: size.width / 2, y: max(paddleOffset, safeAreaBottom + 20))
        addChild(playerPaddle)

        aiPaddle = makePaddle()
        aiPaddle.name = "aiPaddle"
        aiPaddle.position = CGPoint(x: size.width / 2, y: min(size.height - paddleOffset, size.height - safeAreaTop - 20))
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
        ball.physicsBody?.contactTestBitMask = Category.goal.rawValue | Category.paddle.rawValue | Category.wall.rawValue
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
        playerScoreLabel.alpha = 0.5
        playerScoreLabel.text = "0"
        addChild(playerScoreLabel)

        aiScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        aiScoreLabel.fontSize = 48
        aiScoreLabel.fontColor = .white
        aiScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        aiScoreLabel.alpha = 0.5
        aiScoreLabel.text = "0"
        addChild(aiScoreLabel)
    }

    private func createCenterLine() {
        let dashes = 30
        let dashHeight: CGFloat = 4
        let gap = size.height / CGFloat(dashes * 2)
        let path = CGMutablePath()
        let centerX = size.width / 2
        for i in 0..<dashes {
            let y = gap + CGFloat(i) * gap * 2
            path.addRect(CGRect(x: centerX - 1, y: y - dashHeight / 2, width: 2, height: dashHeight))
        }
        let line = SKShapeNode(path: path)
        line.fillColor = .white
        line.strokeColor = .clear
        line.alpha = 0.2
        line.isUserInteractionEnabled = false
        addChild(line)
    }

    private func createMessageLabel() {
        messageLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        messageLabel.fontSize = 28
        messageLabel.fontColor = .white
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.isHidden = true
        addChild(messageLabel)
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        paddleHitFeedback.prepare()
        wallHitFeedback.prepare()
        goalFeedback.prepare()
    }

    // MARK: - Audio

    private func prepareAudio() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        paddleToneBuffer = generateTone(frequency: 480, duration: 0.05, format: format)
        wallToneBuffer = generateTone(frequency: 320, duration: 0.03, format: format)
        scoreToneBuffer = generateTone(frequency: 220, duration: 0.3, format: format)
        winToneBuffer = generateTone(frequency: 660, duration: 0.5, format: format)

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            // Audio unavailable — game still works via haptics
        }
    }

    private func generateTone(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)  // linear fade-out
            data[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.3)
        }
        return buffer
    }

    private func playSound(_ buffer: AVAudioPCMBuffer) {
        guard audioEngine.isRunning else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        if isPlaying {
            isPaused = true
        }
    }

    @objc private func appWillEnterForeground() {
        if isPaused {
            isPaused = false
            lastUpdateTime = 0
        }
    }

    // MARK: - Game Flow

    private func showMessage(_ text: String) {
        messageLabel.text = text
        messageLabel.isHidden = false
        postAccessibilityAnnouncement(text)
    }

    private func postAccessibilityAnnouncement(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func launchBall() {
        isPlaying = true
        messageLabel.isHidden = true
        currentBallSpeed = baseBallSpeed
        rallyCount = 0

        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ball.physicsBody?.velocity = .zero

        let angle = CGFloat.random(in: .pi / 6 ... .pi / 3) * (Bool.random() ? 1 : -1)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let dx = sin(angle) * currentBallSpeed
        let dy = cos(angle) * currentBallSpeed * direction

        ball.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
    }

    private func scored(byPlayer: Bool) {
        isPlaying = false
        ball.physicsBody?.velocity = .zero
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)

        if byPlayer {
            playerScore += 1
            playerScoreLabel.text = "\(playerScore)"
            goalFeedback.notificationOccurred(.success)
        } else {
            aiScore += 1
            aiScoreLabel.text = "\(aiScore)"
            goalFeedback.notificationOccurred(.warning)
        }
        playSound(scoreToneBuffer)

        if playerScore >= winScore {
            playSound(winToneBuffer)
            showMessage("You Win! Tap to Restart")
            resetScores()
        } else if aiScore >= winScore {
            showMessage("You Lose! Tap to Restart")
            resetScores()
        } else {
            let announcement = "Player \(playerScore), Opponent \(aiScore). Tap to Serve"
            showMessage("Tap to Serve")
            postAccessibilityAnnouncement(announcement)
        }
    }

    private func resetScores() {
        playerScore = 0
        aiScore = 0
        playerScoreLabel.text = "0"
        aiScoreLabel.text = "0"
    }

    // MARK: - Paddle Angle Deflection

    private func applyPaddleDeflection(paddle: SKShapeNode) {
        guard var velocity = ball.physicsBody?.velocity else { return }

        // Offset from paddle center: -1 (left edge) to +1 (right edge)
        let offset = (ball.position.x - paddle.position.x) / (paddleWidth / 2)
        let clampedOffset = max(-1, min(1, offset))

        // Max deflection angle: 60 degrees from vertical
        let maxAngle: CGFloat = .pi / 3
        let angle = clampedOffset * maxAngle

        let direction: CGFloat = velocity.dy > 0 ? 1 : -1
        velocity.dx = sin(angle) * currentBallSpeed
        velocity.dy = cos(angle) * currentBallSpeed * direction

        ball.physicsBody?.velocity = velocity
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
        let minVertical = currentBallSpeed * 0.3
        if abs(velocity.dy) < minVertical {
            velocity.dy = velocity.dy >= 0 ? minVertical : -minVertical
        }
        let speed = hypot(velocity.dx, velocity.dy)
        if speed > 0 {
            let scale = currentBallSpeed / speed
            ball.physicsBody?.velocity = CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
        }
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPlaying else { return }

        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let combined = maskA | maskB

        if combined & Category.goal.rawValue != 0 {
            let names = [contact.bodyA.node?.name, contact.bodyB.node?.name]
            if names.contains("topGoal") {
                scored(byPlayer: true)
            } else if names.contains("bottomGoal") {
                scored(byPlayer: false)
            }
        } else if combined == Category.ball.rawValue | Category.paddle.rawValue {
            rallyCount += 1
            currentBallSpeed = min(maxBallSpeed, baseBallSpeed + CGFloat(rallyCount) * speedIncrement)

            let paddleNode = contact.bodyA.categoryBitMask == Category.paddle.rawValue
                ? contact.bodyA.node as? SKShapeNode
                : contact.bodyB.node as? SKShapeNode
            if let paddle = paddleNode {
                applyPaddleDeflection(paddle: paddle)
            }

            paddleHitFeedback.impactOccurred()
            paddleHitFeedback.prepare()
            playSound(paddleToneBuffer)
        } else if combined == Category.ball.rawValue | Category.wall.rawValue {
            wallHitFeedback.impactOccurred()
            wallHitFeedback.prepare()
            playSound(wallToneBuffer)
        }
    }
}
