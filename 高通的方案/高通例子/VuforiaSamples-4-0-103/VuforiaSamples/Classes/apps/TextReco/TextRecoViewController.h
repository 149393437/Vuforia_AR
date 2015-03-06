/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/


#import <UIKit/UIKit.h>
#import "TextRecoEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>
#import "SampleAppMenu.h"

@interface TextRecoViewController : UIViewController <SampleApplicationControl, SampleAppMenuCommandProtocol>{
    CGRect viewFrame;
    CGRect viewQCARFrame;
    TextRecoEAGLView* eaglView;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;

    int ROICenterX;
    int ROICenterY;
    int ROIWidth;
    int ROIHeight;
}

@end
