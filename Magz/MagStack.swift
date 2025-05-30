import UIKit

// A generic UIView that lays out a stack of "card" views
class MagStackView<Item>: UIView {
    
    // MARK: - Properties
    private var items: [Item]
    private var views: [UIView]
    private var builder: (Item) -> UIView

    private let maxItemsDisplayed = 30
    private let scaleDecrement: CGFloat = 0.005
    private let verticalSpacing: CGFloat = 15.0
    private let expandedVerticalSpacing: CGFloat = 100.0

    private var isStacked = true

    // Callbacks
    var onSelect: ((Item) -> Void)?
    
    // MARK: - Init
    
    init(items: [Item], builder: @escaping (Item) -> UIView) {
        self.items = items
        self.builder = builder
        self.views = items.map(builder)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    
    private func setup() {
        for (index, view) in views.enumerated() {
            view.isUserInteractionEnabled = true
            addSubview(view)

            // Tap gesture
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(tap)
            
            // Long press gesture
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            view.addGestureRecognizer(longPress)
            
            // Pan gesture
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            view.addGestureRecognizer(pan)

            // Initial transform
            positionView(view, at: index)
            
            }
    }

    // MARK: - Layout & Transform
    
    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, view) in views.enumerated() {
            positionView(view, at: index)
        }
    }

    private func positionView(_ view: UIView, at index: Int) {
        let yOffset = (isStacked ? verticalSpacing : expandedVerticalSpacing) * CGFloat(-index)
        let scale = isStacked ? 1.0 - (scaleDecrement * CGFloat(index)) : 1.0

        view.transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: yOffset)
            .scaledBy(x: scale, y: scale)

        view.layer.zPosition = Double(views.count - index)
        view.alpha = (isStacked && index >= maxItemsDisplayed) ? 0.0 : 1.0
        view.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        toggleStacking()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let view = gesture.view,
              let index = views.firstIndex(of: view) else { return }
        onSelect?(items[index])
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }

        let translation = gesture.translation(in: self)
        view.transform = view.transform.translatedBy(x: translation.x, y: translation.y)
        gesture.setTranslation(.zero, in: self)

        if gesture.state == .changed {
            let location = gesture.location(in: self)
            if let hitView = hitTest(location, with: nil),
               let index = views.firstIndex(of: hitView) {
                print("Finger over item at index \(index): \(items[index])")
            }
        }
    }
    
    // MARK: - Public

    func toggleStacking() {
        isStacked.toggle()
        UIView.animate(withDuration: 0.3) {
            for (index, view) in self.views.enumerated() {
                self.positionView(view, at: index)
            }
        }
    }
}

