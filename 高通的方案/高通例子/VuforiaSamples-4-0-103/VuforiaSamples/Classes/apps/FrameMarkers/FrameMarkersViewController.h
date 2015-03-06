/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "SampleAppMenu.h"
#import "FrameMarkersEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>

@interface FrameMarkersViewController : UIViewController <SampleApplicationControl, SampleAppMenuCommandProtocol>{
    CGRect viewFrame;
    FrameMarkersEAGLView* eaglView;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;
}

@end
