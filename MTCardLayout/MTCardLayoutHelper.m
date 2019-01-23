#import "MTCardLayoutHelper.h"
#import "UICollectionView+CardLayout.h"

static NSString * const kContentOffsetKeyPath = @"contentOffset";

@interface MTCardLayoutHelper() <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UICollectionView *collectionView;

@property (nonatomic, strong) UITapGestureRecognizer * tapGestureRecognizer;

@end

@implementation MTCardLayoutHelper

- (id)initWithCollectionView:(UICollectionView *)collectionView
{
    self = [super init];
    if (self)
    {
        self.collectionView = collectionView;
        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(handleTapGesture:)];
        self.tapGestureRecognizer.delegate = self;
        [self.collectionView addGestureRecognizer:self.tapGestureRecognizer];
    }
    return self;
}

#pragma mark - Tap gesture

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.tapGestureRecognizer) {
        if ([self.collectionView numberOfItemsInSection:0] == 0) {
            return NO;
        }
        CGPoint point = [gestureRecognizer locationInView:self.collectionView];
        id<UICollectionViewDelegate_Draggable> delegate = (id<UICollectionViewDelegate_Draggable>)self.collectionView.delegate;
        if ([delegate respondsToSelector:@selector(collectionView:shouldRecognizeTapGestureAtPoint:)] &&
            ![delegate collectionView:self.collectionView shouldRecognizeTapGestureAtPoint:point]) {
            return NO;
        }
    }
    
    return YES;
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gestureRecognizer
{
    if (self.viewMode == MTCardLayoutViewModePresenting) {
        [self.collectionView setViewMode:MTCardLayoutViewModeDefault animated:YES completion:nil];
        NSArray *selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
        [selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * indexPath, NSUInteger idx, BOOL *stop) {
            [self.collectionView deselectAndNotifyDelegate:indexPath];
        }];
    } else { // MTCardLayoutViewModeDefault
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[gestureRecognizer locationInView:self.collectionView]];
        if (indexPath) {
            [self.collectionView selectAndNotifyDelegate:indexPath];
        }
    }
}

@end
