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
        
        print(imageSize)
        
        return card
    }
    
    @objc private func cardPan(_ sender: UIPanGestureRecognizer) {
        guard let cardView = sender.view else { return }
        
        let translation = sender.translation(in: view)
        
        switch sender.state {
        case .began, .changed:
            if let originalTransform = cardView.layer.value(forKey: "originalTransform") as? CGAffineTransform {
                // Combine original transform with drag translation
                let dragTransform = originalTransform.translatedBy(x: translation.x, y: translation.y)
                cardView.transform = dragTransform
            }
            
        case .ended, .cancelled, .failed:
            if let originalTransform = cardView.layer.value(forKey: "originalTransform") as? CGAffineTransform {
                // Animate back to original transform
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) {
                    cardView.transform = originalTransform
                }
            }
        default:
            break
        }
    }
}

#Preview {
    CardStackViewController()
}
