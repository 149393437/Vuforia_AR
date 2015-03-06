/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "SampleAppMenu.h"
#import "ImageTargetsEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>

@interface ImageTargetsViewController : UIViewController <SampleApplicationControl, SampleAppMenuCommandProtocol>{
    CGRect viewFrame;
    ImageTargetsEAGLView* eaglView;
    QCAR::DataSet*  dataSetCurrent;
    QCAR::DataSet*  dataSetTarmac;
    QCAR::DataSet*  dataSetStonesAndChips;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;
    
    BOOL switchToTarmac;
    BOOL switchToStonesAndChips;
    BOOL extendedTrackingIsOn;
    
}

@end
