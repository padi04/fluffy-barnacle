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

    private let phosphorGreen = UIColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1.0)

    private let paddleWidth: CGFloat = 100
    private let paddleHeight: CGFloat = 16
    private let touchOffsetY: CGFloat = 40
    private let ballRadius: CGFloat = 10
    private let baseBallSpeed: CGFloat = 400
    private let maxBallSpeed: CGFloat = 650
    private let speedIncrement: CGFloat = 15
    private let aiSpeed: CGFloat = 3.5
    private let winScore = 7

    // MARK: - Nodes

    private var ball: SKShapeNode!
    private var ballGlow: SKEffectNode!
    private var playerPaddle: SKShapeNode!
    private var aiPaddle: SKShapeNode!
    private var playerScoreLabel: SKLabelNode!
    private var aiScoreLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var scanlineOverlay: SKSpriteNode!

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
        backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)

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
        createScanlines()
        createScreenBorder()
        createVignette()
        prepareHaptics()
        prepareAudio()
        observeAppLifecycle()

        showMessage("TAP TO START")
    }

    // MARK: - Visual Setup

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
        playerPaddle.position = CGPoint(x: size.width / 2, y: max(paddleOffset, safeAreaBottom + touchOffsetY))
        addChild(playerPaddle)

        aiPaddle = makePaddle()
        aiPaddle.name = "aiPaddle"
        aiPaddle.position = CGPoint(x: size.width / 2, y: min(size.height - paddleOffset, size.height - safeAreaTop - 20))
        addChild(aiPaddle)
    }

    private func makePaddle() -> SKShapeNode {
        let paddle = SKShapeNode(rectOf: CGSize(width: paddleWidth, height: paddleHeight), cornerRadius: 2)
        paddle.fillColor = phosphorGreen
        paddle.strokeColor = .clear
        paddle.glowWidth = 4
        paddle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: paddleWidth, height: paddleHeight))
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = Category.paddle.rawValue
        paddle.physicsBody?.friction = 0
        paddle.physicsBody?.restitution = 1
        return paddle
    }

    private func createBall() {
        // Glow container
        ballGlow = SKEffectNode()
        ballGlow.shouldRasterize = true
        ballGlow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 8.0])
        ballGlow.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(ballGlow)

        let glowDot = SKShapeNode(circleOfRadius: ballRadius * 1.5)
        glowDot.fillColor = phosphorGreen.withAlphaComponent(0.4)
        glowDot.strokeColor = .clear
        ballGlow.addChild(glowDot)

        // Actual ball
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = phosphorGreen
        ball.strokeColor = .clear
        ball.glowWidth = 2
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
        playerScoreLabel = makeScoreLabel()
        playerScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60)
        addChild(playerScoreLabel)

        aiScoreLabel = makeScoreLabel()
        aiScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        addChild(aiScoreLabel)
    }

    private func makeScoreLabel() -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.fontSize = 64
        label.fontColor = phosphorGreen
        label.alpha = 0.25
        label.text = "0"
        return label
    }

    private func createCenterLine() {
        let dashes = 30
        let dashHeight: CGFloat = 6
        let gap = size.height / CGFloat(dashes * 2)
        let path = CGMutablePath()
        let centerX = size.width / 2
        for i in 0..<dashes {
            let y = gap + CGFloat(i) * gap * 2
            path.addRect(CGRect(x: centerX - 1.5, y: y - dashHeight / 2, width: 3, height: dashHeight))
        }
        let line = SKShapeNode(path: path)
        line.fillColor = phosphorGreen
        line.strokeColor = .clear
        line.alpha = 0.15
        line.isUserInteractionEnabled = false
        addChild(line)
    }

    private func createMessageLabel() {
        messageLabel = SKLabelNode(fontNamed: "Courier-Bold")
        messageLabel.fontSize = 24
        messageLabel.fontColor = phosphorGreen
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.isHidden = true
        addChild(messageLabel)
    }

    private func createScanlines() {
        let scanlineSpacing: CGFloat = 3
        let lineCount = Int(size.height / scanlineSpacing)

        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: size.height), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setFillColor(UIColor.black.cgColor)
        for i in stride(from: 0, to: lineCount, by: 2) {
            ctx.fill(CGRect(x: 0, y: CGFloat(i) * scanlineSpacing, width: 1, height: 1))
        }

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        scanlineOverlay = SKSpriteNode(texture: texture, size: size)
        scanlineOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        scanlineOverlay.alpha = 0.12
        scanlineOverlay.zPosition = 100
        scanlineOverlay.isUserInteractionEnabled = false
        addChild(scanlineOverlay)
    }

    private func createScreenBorder() {
        let border = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: size.height - 16), cornerRadius: 8)
        border.position = CGPoint(x: size.width / 2, y: size.height / 2)
        border.fillColor = .clear
        border.strokeColor = phosphorGreen.withAlphaComponent(0.15)
        border.lineWidth = 2
        border.glowWidth = 3
        border.zPosition = 99
        border.isUserInteractionEnabled = false
        addChild(border)
    }

    private func createVignette() {
        let vignetteSize = max(size.width, size.height) * 1.2
        UIGraphicsBeginImageContextWithOptions(CGSize(width: vignetteSize, height: vignetteSize), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.4, 0.75, 1.0]
        let center = CGPoint(x: vignetteSize / 2, y: vignetteSize / 2)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: vignetteSize / 2, options: .drawsAfterEndLocation)
        }

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()

        let texture = SKTexture(image: image)
        let vignette = SKSpriteNode(texture: texture, size: CGSize(width: vignetteSize, height: vignetteSize))
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.zPosition = 101
        vignette.isUserInteractionEnabled = false
        vignette.blendMode = .multiply
        addChild(vignette)
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        paddleHitFeedback.prepare()
        wallHitFeedback.prepare()
        goalFeedback.prepare()
    }

    // MARK: - Audio

    private func prepareAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        // Square wave tones for retro feel
        paddleToneBuffer = generateSquareTone(frequency: 480, duration: 0.06, format: format)
        wallToneBuffer = generateSquareTone(frequency: 320, duration: 0.04, format: format)
        scoreToneBuffer = generateSquareTone(frequency: 160, duration: 0.35, format: format)
        winToneBuffer = generateArpeggio(frequencies: [330, 415, 523, 660], noteDuration: 0.12, format: format)

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            // Audio engine unavailable
        }
    }

    private func generateSquareTone(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)
            let wave = sin(2.0 * .pi * frequency * t) >= 0 ? 1.0 : -1.0
            data[i] = Float(wave * envelope * 0.2)
        }
        return buffer
    }

    private func generateArpeggio(frequencies: [Double], noteDuration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let totalDuration = noteDuration * Double(frequencies.count)
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let noteIndex = min(Int(t / noteDuration), frequencies.count - 1)
            let freq = frequencies[noteIndex]
            let noteT = t - Double(noteIndex) * noteDuration
            let envelope = max(0, 1.0 - noteT / noteDuration)
            let wave = sin(2.0 * .pi * freq * t) >= 0 ? 1.0 : -1.0
            data[i] = Float(wave * envelope * 0.18)
        }
        return buffer
    }

    private func playSound(_ buffer: AVAudioPCMBuffer) {
        guard audioEngine?.isRunning == true else { return }
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
        if let engine = audioEngine, !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
            playerNode?.play()
        }
    }

    // MARK: - Game Flow

    private func showMessage(_ text: String) {
        messageLabel.text = text
        messageLabel.isHidden = false
        // Blink the message like an arcade attract screen
        messageLabel.removeAllActions()
        messageLabel.alpha = 1.0
        messageLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.5),
            .fadeAlpha(to: 1.0, duration: 0.5)
        ])))
        postAccessibilityAnnouncement(text)
    }

    private func postAccessibilityAnnouncement(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func launchBall() {
        isPlaying = true
        messageLabel.isHidden = true
        messageLabel.removeAllActions()
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
            flashLabel(playerScoreLabel)
        } else {
            aiScore += 1
            aiScoreLabel.text = "\(aiScore)"
            goalFeedback.notificationOccurred(.warning)
            flashLabel(aiScoreLabel)
        }
        playSound(scoreToneBuffer)

        if playerScore >= winScore {
            playSound(winToneBuffer)
            showMessage("YOU WIN! TAP TO RESTART")
            resetScores()
        } else if aiScore >= winScore {
            showMessage("YOU LOSE! TAP TO RESTART")
            resetScores()
        } else {
            let announcement = "Player \(playerScore), Opponent \(aiScore). Tap to Serve"
            showMessage("TAP TO SERVE")
            postAccessibilityAnnouncement(announcement)
        }
    }

    private func flashLabel(_ label: SKLabelNode) {
        label.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.05),
            .fadeAlpha(to: 0.25, duration: 0.4)
        ]))
    }

    private func flashScreen() {
        let flash = SKSpriteNode(color: phosphorGreen.withAlphaComponent(0.08), size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 98
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
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

        let offset = (ball.position.x - paddle.position.x) / (paddleWidth / 2)
        let clampedOffset = max(-1, min(1, offset))

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
        let pos = touch.location(in: self)
        movePaddle(to: pos.x, touchY: pos.y)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isPlaying else { return }
        let pos = touch.location(in: self)
        movePaddle(to: pos.x, touchY: pos.y)
    }

    private func movePaddle(to x: CGFloat, touchY: CGFloat) {
        guard touchY < size.height / 2 else { return }
        playerPaddle.position.x = max(paddleWidth / 2, min(size.width - paddleWidth / 2, x))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / 60.0
        lastUpdateTime = currentTime

        guard isPlaying else { return }

        // AI tracks the ball
        let diff = ball.position.x - aiPaddle.position.x
        let newX = aiPaddle.position.x + diff * aiSpeed * CGFloat(dt) * 4
        aiPaddle.position.x = max(paddleWidth / 2, min(size.width - paddleWidth / 2, newX))

        // Ball glow follows ball
        ballGlow.position = ball.position

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
            flashScreen()
        } else if combined == Category.ball.rawValue | Category.wall.rawValue {
            wallHitFeedback.impactOccurred()
            wallHitFeedback.prepare()
            playSound(wallToneBuffer)
        }
    }
}
