/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <UIKit/UIKit.h>
#import "SampleAppMenu.h"
#import "VirtualButtonsEAGLView.h"
#import "SampleApplicationSession.h"
#import <QCAR/DataSet.h>



@interface VirtualButtonsViewController : UIViewController <SampleApplicationControl, SampleAppMenuCommandProtocol>{
    CGRect viewFrame;
    VirtualButtonsEAGLView* eaglView;
    UITapGestureRecognizer * tapGestureRecognizer;
    SampleApplicationSession * vapp;
    
    QCAR::DataSet*  dataSet;

    bool buttonStateChanged;
    bool buttonActivated[NB_BUTTONS];
}

@end
