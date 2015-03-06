/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "SampleAppMenu.h"
#import "ObjectRecoEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>

@interface ObjectRecoViewController : UIViewController <SampleApplicationControl, SampleAppMenuCommandProtocol>{
    CGRect viewFrame;
    ObjectRecoEAGLView* eaglView;
    QCAR::DataSet*  currentDataSet;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;
    BOOL extendedTrackingIsOn;
}

@end
