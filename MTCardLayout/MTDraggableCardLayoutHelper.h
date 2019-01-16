#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MTDraggableCardLayoutHelper : NSObject

@property (nonatomic, readonly) UICollectionViewLayoutAttributes *movingItemAttributes;
@property (nonatomic, readonly) NSIndexPath *toIndexPath;
@property (nonatomic, readonly) CGRect movingItemFrame;
@property (nonatomic, readonly) CGFloat movingItemAlpha;

- (id)initWithCollectionView:(UICollectionView *)collectionView;

@end
