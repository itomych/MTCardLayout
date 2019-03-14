#import "MTCardLayout.h"
#import "UICollectionView+CardLayout.h"

@interface UICollectionView (CardLayoutPrivate)
- (void)cardLayoutCleanup;
@end

@interface MTCardLayout ()

@end

@implementation MTCardLayout

- (id)init {
    self = [super init];

    if (self) {
        [self useDefaultMetricsAndInvalidate:NO];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];

    if (self) {
        [self useDefaultMetricsAndInvalidate:NO];
    }

    return self;
}

- (void)dealloc {
    [self.collectionView cardLayoutCleanup];
}

#pragma mark - Initialization

- (void)useDefaultMetricsAndInvalidate:(BOOL)invalidate {
    MTCardLayoutMetrics m;
    MTCardLayoutEffects e;

    m.presentingInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    m.listingInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    m.minimumVisibleHeight = 70;
    m.flexibleTop = 0.0;
    m.stackedVisibleHeight = 0.0;
    m.maxStackedCards = 5;
    m.headerSize = CGSizeZero;

    e.inheritance = 0.10;
    e.presentingHeaderAlpha = 0.1;
    e.sticksTop = NO;
    e.bouncesTop = YES;
    e.spreading = NO;

    _metrics = m;
    _effects = e;

    if (invalidate) [self invalidateLayout];
}

#pragma mark - Accessors

- (void)setMetrics:(MTCardLayoutMetrics)metrics {
    _metrics = metrics;

    [self invalidateLayout];
}

- (void)setEffects:(MTCardLayoutEffects)effects {
    _effects = effects;

    [self invalidateLayout];
}

#pragma mark - Layout

- (void)prepareLayout {
    _metrics.visibleHeight = _metrics.minimumVisibleHeight;
    if (_effects.spreading) {
        NSInteger numberOfCards = [self.collectionView numberOfItemsInSection:0];
        if (numberOfCards > 0) {
            CGFloat height = (self.collectionView.frame.size.height - self.collectionView.contentInset.top - _metrics.flexibleTop) / numberOfCards + _metrics.headerSize.height;
            if (height > _metrics.visibleHeight) _metrics.visibleHeight = height;
        }
    }
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath selectedIndexPath:(NSIndexPath *)selectedIndexPath viewMode:(MTCardLayoutViewMode)viewMode headerInfo:(CGSize)headerSize {
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.zIndex = indexPath.item + 1;
    attributes.transform3D = CATransform3DMakeTranslation(0, 0, indexPath.item * 0.0001);

    if (self.collectionView.viewMode == MTCardLayoutViewModePresenting) {
        if (selectedIndexPath && [selectedIndexPath isEqual:indexPath]) {
            // Layout selected cell (normal size)
            attributes.frame = frameForSelectedCard(self.collectionView.bounds, self.collectionView.contentInset, _metrics);
        } else {
            // Layout unselected cell (bottom-stuck)
            attributes.frame = frameForUnselectedCard(indexPath, selectedIndexPath, self.collectionView.bounds, _metrics);
        }
    } else // stack mode
    {
        // Layout collapsed cells (collapsed size)
        attributes.frame = frameForCardAtIndex(indexPath, self.collectionView.bounds, [self collectionViewContentSize], self.collectionView.contentInset, _metrics, _effects, headerSize);
    }

    attributes.hidden = attributes.frame.size.height == 0;

    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
    return [self layoutAttributesForItemAtIndexPath:indexPath selectedIndexPath:[selectedIndexPaths firstObject] viewMode:self.collectionView.viewMode headerInfo:self.metrics.headerSize];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    CGRect effectiveBounds = self.collectionView.bounds;
    effectiveBounds.origin.y += self.collectionView.contentInset.top;
    effectiveBounds.origin.y += _metrics.listingInsets.top;
    effectiveBounds.size.height -= _metrics.listingInsets.bottom;
    effectiveBounds.size.height += _metrics.headerSize.height;
    rect = CGRectIntersection(rect, effectiveBounds);

    if (rect.origin.x == INFINITY || rect.origin.y == INFINITY) {
        return nil;
    }
    NSInteger numberOfItems = [self numberOfItemsInCollectionViewSection:0];

    NSRange range = rangeForVisibleCells(rect, numberOfItems, _metrics);
    NSMutableArray *cells = [NSMutableArray arrayWithCapacity:range.length + 3];

    NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];

    UICollectionViewLayoutAttributes *headerAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    [cells addObject:headerAttributes];
    for (NSUInteger item = range.location; item < (range.location + range.length); item++) {
        [cells addObject:[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0] selectedIndexPath:selectedIndexPath viewMode:self.collectionView.viewMode headerInfo:headerAttributes.frame.size]];
    }

    // selected item is out of range
    if (self.collectionView.viewMode == MTCardLayoutViewModePresenting && selectedIndexPath && (selectedIndexPath.item < range.location || selectedIndexPath.item >= range.location + range.length)) {
        [cells addObject:[self layoutAttributesForItemAtIndexPath:selectedIndexPath selectedIndexPath:selectedIndexPath viewMode:self.collectionView.viewMode headerInfo:CGSizeZero]];
    }

    return cells;
}

- (CGSize)collectionViewContentSize {
    return collectionViewSize(self.collectionView.bounds,
                              self.collectionView.contentInset,
                              [self numberOfItemsInCollectionViewSection:0],
                              _metrics);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

#pragma mark - Postioning

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    CGPoint targetContentOffset = proposedContentOffset;

    if (self.collectionView.scrollEnabled) {
        targetContentOffset.y += self.collectionView.contentInset.top;
        CGFloat flexibleHeight = _metrics.flexibleTop;
        if (targetContentOffset.y < flexibleHeight) {
            // Snap to either 0 or flexibleHeight offset when the position is somewhere in between
            targetContentOffset.y = (targetContentOffset.y < flexibleHeight / 2) ? 0.0 : flexibleHeight;
        } else {
            if (_metrics.visibleHeight > 0) {
                targetContentOffset.y = roundf((targetContentOffset.y - flexibleHeight) / _metrics.visibleHeight) * _metrics.visibleHeight + flexibleHeight;
            }
        }
        targetContentOffset.y -= self.collectionView.contentInset.top;
    }

    return targetContentOffset;
}

#pragma mark Cell visibility

NSRange rangeForVisibleCells(CGRect rect, NSInteger count, MTCardLayoutMetrics m) {
    rect.origin.y -= m.flexibleTop + m.headerSize.height;
    NSInteger min = (m.visibleHeight == 0) ? 0 : floor(rect.origin.y < 0 ? 0 : rect.origin.y / m.visibleHeight);
    NSInteger max = (m.visibleHeight == 0) ? count : ceil((rect.origin.y + rect.size.height) < 0 ? 0 : (rect.origin.y + rect.size.height) / m.visibleHeight);

    max = (max > count) ? count : max;

    min = (min < 0) ? 0 : min;
    min = (min < max) ? min : max;

    if (min == max) {
        min = max - 1 < 0 ? 0 : max - 1;
    }

    NSRange r = NSMakeRange(min, max - min);
    return r;
}

CGSize collectionViewSize(CGRect bounds, UIEdgeInsets contentInset, NSInteger count, MTCardLayoutMetrics m) {
    CGFloat additionalBottomCellHeight = 5;
    CGFloat height = count * m.visibleHeight + m.flexibleTop + m.headerSize.height + additionalBottomCellHeight;
    return CGSizeMake(bounds.size.width, height);
}

#pragma mark Cell positioning

/// Normal collapsed cell, with bouncy animations on top
CGRect frameForCardAtIndex(NSIndexPath *indexPath, CGRect b, CGSize collectionViewContentSize, UIEdgeInsets contentInset, MTCardLayoutMetrics m, MTCardLayoutEffects e, CGSize header) {
    CGRect f = UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(b, contentInset), m.presentingInsets);
    f.origin.y = indexPath.item * m.visibleHeight + header.height;
    f.size.height = m.visibleHeight + collectionViewContentSize.height;
        
    if (b.origin.y + contentInset.top < 0 && e.inheritance > 0.0 && e.bouncesTop) {
        if (indexPath.section == 0 && indexPath.item == 0) {
            f.origin.y = (b.origin.y + contentInset.top) * e.inheritance/2.0 + m.flexibleTop + m.listingInsets.top + header.height;
        }
        else {
            f.origin.y -= (b.origin.y + contentInset.top) * indexPath.item * e.inheritance;
        }
    }

    return f;
}

CGRect frameForSelectedCard(CGRect b, UIEdgeInsets contentInset, MTCardLayoutMetrics m) {
    return UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(b, contentInset), m.presentingInsets);
}

/// Bottom-stack card
CGRect frameForUnselectedCard(NSIndexPath *indexPath, NSIndexPath *indexPathSelected, CGRect b, MTCardLayoutMetrics m) {
    NSInteger firstVisibleItem = ceil((b.origin.y - m.flexibleTop - m.listingInsets.top) / m.visibleHeight);
    if (firstVisibleItem < 0) firstVisibleItem = 0;

    NSInteger itemOrder = indexPath.item - firstVisibleItem;
    if (indexPathSelected && indexPath.item > indexPathSelected.item) itemOrder--;

    CGFloat bottomStackedTotalHeight = m.stackedVisibleHeight * m.maxStackedCards;

    CGRect f = UIEdgeInsetsInsetRect(b, m.presentingInsets);
    f.origin.y = b.origin.y + b.size.height + m.stackedVisibleHeight * itemOrder - bottomStackedTotalHeight;
    if (indexPath.item < firstVisibleItem) {
        f.size.height = 0;
    }

    return f;
}

- (NSInteger)numberOfItemsInCollectionViewSection:(NSInteger)section {
    return
        [self.collectionView numberOfSections] > section ?
        [self.collectionView numberOfItemsInSection:section] :
        0;
}

@end
