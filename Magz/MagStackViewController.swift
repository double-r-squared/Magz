import UIKit

class CardStackViewController: UIViewController {
    var cards: [(CardModel, UIImage)] = []
    let service = ArchiveService()
    let maxCardsVisible = 30
    let scaleDecrement: CGFloat = 0.015
    let verticalSpacing: CGFloat = 20
    
    private func loadThumbnails(for models: [CardModel], completion: @escaping ([(CardModel, UIImage)]) -> Void) {
        var results: [(CardModel, UIImage)] = []
        let group = DispatchGroup()
        
        for model in models.prefix(maxCardsVisible) {
            guard let url = model.thumbnailURL else { continue }
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                if let data = data, let image = UIImage(data: data) {
                    results.append((model, image))
                }
            }.resume()
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //TODO: ADD GRADIENT BACKGROUND OF WHATEVER IMAGE IS INDEX 0 (First/or selected)
        
        view.backgroundColor = .systemBackground
        
        service.fetchMagazines { [weak self] models in
            self?.loadThumbnails(for: models) { loadedCards in
                self?.cards = loadedCards
                self?.layoutCardStack()
            }
        }
    }
    
    private func layoutCardStack() {
        for (index, (model, image)) in cards.enumerated() {
            let cardView = createCardView(for: model, image: image)
            
            let scale = 1.0 - (CGFloat(index) * scaleDecrement)
            let yOffset = CGFloat(index) * verticalSpacing
            
            cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: 0, y: -yOffset))
            cardView.layer.setValue(cardView.transform, forKey: "originalTransform")
            cardView.layer.zPosition = CGFloat(maxCardsVisible - index)
            
            view.insertSubview(cardView, at: 0)
        }
    }
    
    
    private func createCardView(for model: CardModel, image: UIImage) -> UIView {
        let imageSize = image.size
        let maxWidth = view.bounds.width - 20
        let scaleFactor = maxWidth / imageSize.width
        let scaledHeight = imageSize.height * scaleFactor
        
        let card = UIView(frame: CGRect(x: 10, y: 450, width: maxWidth, height: scaledHeight))
        card.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 4
        card.clipsToBounds = true
        
        let imageView = UIImageView(frame: card.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(imageView)
        
        // Load thumbnail image asynchronously
        if let url = model.thumbnailURL {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, let image = UIImage(data: data), error == nil else {
                    print("Image load error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }.resume()
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(cardPan(_:)))
        card.addGestureRecognizer(pan)
        
        return card
    }
    
    @objc private func cardPan(_ sender: UIPanGestureRecognizer) {
        guard let cardView = sender.view else { return }
        
        let translation = sender.translation(in: view)
        let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
        let screenHeight = UIScreen.main.bounds.height
        
        let rightHapticThreshold: CGFloat = 100.0
        let downHapticThreshold: CGFloat = 150.0
        let upHapticThreshold: CGFloat = 100.0
        let dismissThreshold: CGFloat = 250.0
        
        switch sender.state {
        case .began:
            // Store original transform if not already stored
            if cardView.layer.value(forKey: "originalTransform") == nil {
                cardView.layer.setValue(cardView.transform, forKey: "originalTransform")
            }
            
        case .changed:
            if let originalTransform = cardView.layer.value(forKey: "originalTransform") as? CGAffineTransform {
                // Apply translation
                cardView.transform = originalTransform.translatedBy(x: translation.x, y: translation.y)
                
                //MARK: RIGHT BEHAVIOR
                if translation.x > rightHapticThreshold {
                    if cardView.layer.value(forKey: "rightHapticTriggered") as? Bool != true {
                        hapticFeedback.impactOccurred()
                        cardView.layer.setValue(true, forKey: "rightHapticTriggered")
                    }
                    
                    //TODO: HAVE ALL OTHER ITEMS MOVE DOWN AND FADE AWAY WHEN SELECTED
                    //TODO: ENTER PDF VIEW
                    
                    // Calculate transparency for other cards based on right drag progress
                    let progress = min(1.0, (translation.x - rightHapticThreshold) / (view.bounds.width/2 - rightHapticThreshold))
                    setTransparencyForOtherCards(relativeTo: cardView, alpha: 1 - progress)
                } else {
                    cardView.layer.setValue(false, forKey: "rightHapticTriggered")
                    // Reset transparency if not dragging right enough
                    setTransparencyForOtherCards(relativeTo: cardView, alpha: 1.0)
                }
                
                //MARK: UP BEHAVIOR
                if translation.y < upHapticThreshold {
                    // Haptic feedback
                    if cardView.layer.value(forKey: "upHapticTriggered") as? Bool != true {
                        hapticFeedback.impactOccurred()
                        cardView.layer.setValue(true, forKey: "upHapticTriggered")
                    }
                    
                    //TODO: Make cards that are infront completly transparent and the cards behind darkened
                    
                    // Visual feedback - fade out other cards as dragged further up
                    let progress = min(1.0, (translation.y - upHapticThreshold) / (view.bounds.width/2 - upHapticThreshold))
                    setTransparencyForOtherCards(relativeTo: cardView, alpha: 1 - progress)
                } else {
                    // Reset transparency if not dragging up enough
                    setTransparencyForOtherCards(relativeTo: cardView, alpha: 1.0)
                }
                
                //MARK: DOWN BEHAVIOR
                if translation.y > downHapticThreshold {
                    // Haptic feedback
                    if cardView.layer.value(forKey: "downHapticTriggered") as? Bool != true {
                        hapticFeedback.impactOccurred()
                        cardView.layer.setValue(true, forKey: "downHapticTriggered")
                    }
                    
                    // Visual feedback - fade out as dragged further down
                    let progress = min(1.0, (translation.y - downHapticThreshold) / (dismissThreshold - downHapticThreshold))
                    cardView.alpha = 1.0 - (progress * 0.8) // Fades to 0.2 alpha at dismiss threshold
                } else {
                    cardView.layer.setValue(false, forKey: "downHapticTriggered")
                    cardView.alpha = 1.0
                }
            }
            
        case .ended, .cancelled, .failed:
            if let originalTransform = cardView.layer.value(forKey: "originalTransform") as? CGAffineTransform {
                let velocity = sender.velocity(in: view)
                
                // Check if should dismiss (dragged down past threshold or fast swipe down)
                if translation.y > dismissThreshold || velocity.y > 1000 {
                    // Dismiss animation
                    UIView.animate(withDuration: 0.3, animations: {
                        cardView.transform = originalTransform.translatedBy(x: 0, y: screenHeight)
                        cardView.alpha = 0
                    }) { _ in
                        cardView.removeFromSuperview()
                        // Call your completion handler here if needed
                    }
                } else {
                    // Spring back to original position
                    UIView.animate(withDuration: 0.6, delay: 0,
                                   usingSpringWithDamping: 0.6,
                                   initialSpringVelocity: 0.8,
                                   options: [.curveEaseOut],
                                   animations: {
                        cardView.transform = originalTransform
                        cardView.alpha = 1.0
                        // Reset all other cards' transparency
                        self.setTransparencyForOtherCards(relativeTo: cardView, alpha: 1.0)
                    })
                }
            }
            
            // Reset all flags
            cardView.layer.setValue(false, forKey: "rightHapticTriggered")
            cardView.layer.setValue(false, forKey: "downHapticTriggered")
            cardView.layer.setValue(false, forKey: "upHapticTriggered")
            
        default:
            break
        }
    }
    
    private func setTransparencyForOtherCards(relativeTo currentCard: UIView, alpha: CGFloat) {
        UIView.animate(withDuration: 0.2) {
            for subview in self.view.subviews {
                // Skip the current card and any non-card views
                if subview != currentCard && subview.gestureRecognizers?.contains(where: { $0 is UIPanGestureRecognizer }) == true {
                    subview.alpha = alpha
                }
            }
        }
    }
}

#Preview {
    CardStackViewController()
}
