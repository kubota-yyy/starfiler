protocol MediaKeyActionDelegate: AnyObject {
    func mediaCollectionView(_ collectionView: MediaCollectionView, didTrigger action: KeyAction) -> Bool
}
