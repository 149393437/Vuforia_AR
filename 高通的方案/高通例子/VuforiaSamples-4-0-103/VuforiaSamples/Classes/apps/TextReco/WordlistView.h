/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/



#import <UIKit/UIKit.h>

// Utility class used to contain words that are stored in a single
// '\n'-separated string
@interface DisplayWords : NSObject {
@public
    NSMutableString* words;
    NSUInteger count;
}

@end


// WordListView class
@interface WordlistView : UIView {
@private
    UITextView* textView;
    CGFloat minFontSize;
    CGFloat maxFontSize;

    int marginWidth;
    int loupeHeight;
    int loupeWidth;
    int nonSearchableAreaHeight;
}


// --- Public methods ---
- (void)setWordsToDisplay:(DisplayWords*)words;

@end
