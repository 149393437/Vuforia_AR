/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "SampleAppMenu.h"
#import "UserDefinedTargetsEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>
#import "RefFreeFrame.h"
#import "CustomToolbar.h"

@interface UserDefinedTargetsViewController : UIViewController <SampleApplicationControl, CustomToolbarDelegateProtocol, SampleAppMenuCommandProtocol, UIGestureRecognizerDelegate>{
    CGRect viewFrame;
    UserDefinedTargetsEAGLView* eaglView;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;
    
    QCAR::DataSet* dataSetUserDef;
    RefFreeFrame * refFreeFrame;
    CustomToolbar *toolbar;

    BOOL extendedTrackingIsOn;
}

@end
