/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/


#import <Foundation/Foundation.h>

@protocol CustomToolbarDelegateProtocol <NSObject>

-(void)cancelButtonWasPressed;
-(void)actionButtonWasPressed;

@end
