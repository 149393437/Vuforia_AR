/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import "SampleAppAppDelegate.h"
#import "CylinderTargetsViewController.h"
#import <QCAR/QCAR.h>
#import <QCAR/TrackerManager.h>
#import <QCAR/ObjectTracker.h>
#import <QCAR/DataSet.h>
#import <QCAR/Trackable.h>
#import <QCAR/CameraDevice.h>

@interface CylinderTargetsViewController ()

@end

@implementation CylinderTargetsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
        
        // Custom initialization
        self.title = @"Cylinder Targets";
        // Create the EAGLView with the screen dimensions
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        viewFrame = screenBounds;
        
        // If this device has a retina display, scale the view bounds that will
        // be passed to QCAR; this allows it to calculate the size and position of
        // the viewport correctly when rendering the video background
        if (YES == vapp.isRetinaDisplay) {
            viewFrame.size.width *= 2.0;
            viewFrame.size.height *= 2.0;
        }
        
        // a single tap will trigger a single autofocus operation
        tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(autofocus:)];
        
        
        // we use the iOS notification to pause/resume the AR when the application goes (or comeback from) background
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(pauseAR)
         name:UIApplicationWillResignActiveNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(resumeAR)
         name:UIApplicationDidBecomeActiveNotification
         object:nil];
        
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tapGestureRecognizer release];
    
    [vapp release];
    [eaglView release];
    
    [super dealloc];
}


- (void) pauseAR {
    NSError * error = nil;
    if (![vapp pauseAR:&error]) {
        NSLog(@"Error pausing AR:%@", [error description]);
    }
}

- (void) resumeAR {
    NSError * error = nil;
    if(! [vapp resumeAR:&error]) {
        NSLog(@"Error resuming AR:%@", [error description]);
    }
    // on resume, we reset the flash and the associated menu item
    QCAR::CameraDevice::getInstance().setFlashTorchMode(false);
    SampleAppMenu * menu = [SampleAppMenu instance];
    [menu setSelectionValueForCommand:C_FLASH value:false];
}


- (void)loadView
{
    // Create the EAGLView
    eaglView = [[CylinderTargetsEAGLView alloc] initWithFrame:viewFrame appSession:vapp];
    [self setView:eaglView];
    SampleAppAppDelegate *appDelegate = (SampleAppAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = eaglView;
    
    // show loading animation while AR is being initialized
    [self showLoadingAnimation];
    
    // initialize the AR session
    [vapp initAR:QCAR::GL_20 ARViewBoundsSize:viewFrame.size orientation:UIInterfaceOrientationPortrait];
    
    
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self prepareMenu];

  // Do any additional setup after loading the view.
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    NSLog(@"self.navigationController.navigationBarHidden: %s", self.navigationController.navigationBarHidden ? "Yes" : "No");
}

- (void)viewWillDisappear:(BOOL)animated {
    // cleanup menu
    [[SampleAppMenu instance]clear];

    [vapp stopAR:nil];
    // Be a good OpenGL ES citizen: now that QCAR is paused and the render
    // thread is not executing, inform the root view controller that the
    // EAGLView should finish any OpenGL ES commands
    [eaglView finishOpenGLESCommands];
	
    SampleAppAppDelegate *appDelegate = (SampleAppAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = nil;

    [super viewWillDisappear:animated];
}

- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  Inform the EAGLView
    [eaglView finishOpenGLESCommands];
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Inform the EAGLView
    [eaglView freeOpenGLESResources];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - loading animation

- (void) showLoadingAnimation {
    CGRect mainBounds = [[UIScreen mainScreen] bounds];
    CGRect indicatorBounds = CGRectMake(mainBounds.size.width / 2 - 12,
                                        mainBounds.size.height / 2 - 12, 24, 24);
    UIActivityIndicatorView *loadingIndicator = [[[UIActivityIndicatorView alloc]
                                                  initWithFrame:indicatorBounds]autorelease];
    
    loadingIndicator.tag  = 1;
    loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [eaglView addSubview:loadingIndicator];
    [loadingIndicator startAnimating];
}

- (void) hideLoadingAnimation {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
}


#pragma mark - SampleApplicationControl

// Initialize the application trackers        
- (bool) doInitTrackers {
    // Initialize the image or marker tracker
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    
    // Image Tracker...
    QCAR::Tracker* trackerBase = trackerManager.initTracker(QCAR::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Failed to initialize ObjectTracker.");
        return NO;
    }
    return YES;
}

// load the data associated to the trackers
- (bool) doLoadTrackersData {
    return [self loadAndActivateImageTrackerDataSet:@"sodacan.xml"];
}

// start the application trackers
- (bool) doStartTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::ObjectTracker::getClassType());
    if(tracker == 0) {
        return NO;
    }
    tracker->start();
    return YES;
}

// callback called when the initailization of the AR is done
- (void) onInitARDone:(NSError *)initError {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
    
    if (initError == nil) {
        NSError * error = nil;
        [vapp startAR:QCAR::CameraDevice::CAMERA_BACK error:&error];
        
        // by default, we try to set the continuous auto focus mode
        // and we update menu to reflect the state of continuous auto-focus
        bool isContinuousAutofocus = QCAR::CameraDevice::getInstance().setFocusMode(QCAR::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
        SampleAppMenu * menu = [SampleAppMenu instance];
        [menu setSelectionValueForCommand:C_AUTOFOCUS value:isContinuousAutofocus];
        

    } else {
        NSLog(@"Error initializing AR:%@", [initError description]);
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[initError localizedDescription]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [alert release];
        });
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kMenuDismissViewController" object:nil];
}

// update from the QCAR loop
- (void) onQCARUpdate: (QCAR::State *) state {
}

// stop your trackerts
- (bool) doStopTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::ObjectTracker::getClassType());
    
    if (NULL == tracker) {
        NSLog(@"ERROR: failed to get the tracker from the tracker manager");
        return NO;
    }
	
    tracker->stop();
    NSLog(@"INFO: successfully stopped tracker");
    return YES;
}

// unload the data associated to your trackers
- (bool) doUnloadTrackersData {
    if (dataSet != NULL) {
        // Get the image tracker:
        QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
        QCAR::ObjectTracker* objectTracker = static_cast<QCAR::ObjectTracker*>(trackerManager.getTracker(QCAR::ObjectTracker::getClassType()));
        
        if (objectTracker == NULL)
        {
            NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
            return NO;
        }
        // Activate the data set:
        if (!objectTracker->deactivateDataSet(dataSet))
        {
            NSLog(@"Failed to deactivate data set.");
        }
        // Destroy the data set:
        if (!objectTracker->destroyDataSet(dataSet))
        {
            NSLog(@"Failed to destroy data set.");
        }
        dataSet = NULL;
    }
    return YES;
}

// deinitialize your trackers
- (bool) doDeinitTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    trackerManager.deinitTracker(QCAR::ObjectTracker::getClassType());
    return YES;
}

- (void)autofocus:(UITapGestureRecognizer *)sender
{
    [self performSelector:@selector(cameraPerformAutoFocus) withObject:nil afterDelay:.4];
}

- (void)cameraPerformAutoFocus
{
    QCAR::CameraDevice::getInstance().setFocusMode(QCAR::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
}

// Load the image tracker data set
- (BOOL)loadAndActivateImageTrackerDataSet:(NSString*)dataFile
{
    NSLog(@"loadAndActivateImageTrackerDataSet (%@)", dataFile);
    BOOL ret = YES;
    dataSet = NULL;
    
    // Get the QCAR tracker manager image tracker
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ObjectTracker* objectTracker = static_cast<QCAR::ObjectTracker*>(trackerManager.getTracker(QCAR::ObjectTracker::getClassType()));
    
    if (NULL == objectTracker) {
        NSLog(@"ERROR: failed to get the ObjectTracker from the tracker manager");
        ret = NO;
    } else {
        dataSet = objectTracker->createDataSet();
        
        if (NULL != dataSet) {
            NSLog(@"INFO: successfully loaded data set");
            
            // Load the data set from the app's resources location
            if (!dataSet->load([dataFile cStringUsingEncoding:NSASCIIStringEncoding], QCAR::STORAGE_APPRESOURCE)) {
                NSLog(@"ERROR: failed to load data set");
                objectTracker->destroyDataSet(dataSet);
                dataSet = NULL;
                ret = NO;
            } else {
                // Activate the data set
                if (objectTracker->activateDataSet(dataSet)) {
                    NSLog(@"INFO: successfully activated data set");
                }
                else {
                    NSLog(@"ERROR: failed to activate data set");
                    ret = NO;
                }
            }
        }
        else {
            NSLog(@"ERROR: failed to create data set");
            ret = NO;
        }
        
    }
    
    return ret;
}
    
- (BOOL) setExtendedTrackingForDataSet:(QCAR::DataSet *)theDataSet start:(BOOL) start {
    BOOL result = YES;
    for (int tIdx = 0; tIdx < theDataSet->getNumTrackables(); tIdx++) {
        QCAR::Trackable* trackable = theDataSet->getTrackable(tIdx);
        if (start) {
            if (!trackable->startExtendedTracking())
            {
                NSLog(@"Failed to start extended tracking on: %s", trackable->getName());
                result = false;
            }
        } else {
            if (!trackable->stopExtendedTracking())
            {
                NSLog(@"Failed to stop extended tracking on: %s", trackable->getName());
                result = false;
            }
        }
    }
    return result;
}
    
    

#pragma mark - left menu

typedef enum {
    C_EXTENDED_TRACKING,
    C_AUTOFOCUS,
    C_FLASH,
    C_CAMERA_FRONT,
    C_CAMERA_REAR
} MENU_COMMAND;

- (void) prepareMenu {
    
    SampleAppMenu * menu = [SampleAppMenu prepareWithCommandProtocol:self title:@"Cylinder Targets"];
    SampleAppMenuGroup * group;
    
    group = [menu addGroup:@""];
    [group addTextItem:@"Vuforia Samples" command:-1];

    group = [menu addGroup:@""];
    [group addSelectionItem:@"Extended Tracking" command:C_EXTENDED_TRACKING isSelected:NO];
    [group addSelectionItem:@"Autofocus" command:C_AUTOFOCUS isSelected:NO];
    [group addSelectionItem:@"Flash" command:C_FLASH isSelected:NO];

    group = [menu addSelectionGroup:@"CAMERA"];
    [group addSelectionItem:@"Front" command:C_CAMERA_FRONT isSelected:NO];
    [group addSelectionItem:@"Rear" command:C_CAMERA_REAR isSelected:YES];
}

- (bool) menuProcess:(SampleAppMenu *) menu command:(int) command value:(bool) value{
    bool result = true;
    NSError * error = nil;

    switch(command) {
        case C_FLASH:
            if (!QCAR::CameraDevice::getInstance().setFlashTorchMode(value)) {
                result = false;
            }
            break;
        
        case C_EXTENDED_TRACKING:
            result = [self setExtendedTrackingForDataSet:dataSet start:value];
            if (result) {
                [eaglView setOffTargetTrackingMode:value];
            }
        break;
        
        case C_CAMERA_FRONT:
        case C_CAMERA_REAR:
            if ([vapp stopCamera:&error]) {
                result = [vapp startAR:(command == C_CAMERA_FRONT) ? QCAR::CameraDevice::CAMERA_FRONT:QCAR::CameraDevice::CAMERA_BACK error:&error];
            } else {
                result = false;
            }
            if (result) {
                // if the camera switch worked, the flash will be off
                [menu setSelectionValueForCommand:C_FLASH value:false];
            }

            break;
            
        case C_AUTOFOCUS: {
            int focusMode = (YES == value) ? QCAR::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO : QCAR::CameraDevice::FOCUS_MODE_NORMAL;
            result = QCAR::CameraDevice::getInstance().setFocusMode(focusMode);
        }
            break;
            
        default:
            result = false;
            break;
    }
    return result;
}

@end

