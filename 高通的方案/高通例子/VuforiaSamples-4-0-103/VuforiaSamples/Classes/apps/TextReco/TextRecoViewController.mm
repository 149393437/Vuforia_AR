/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import "SampleAppAppDelegate.h"
#import "TextRecoViewController.h"
#import "SampleApplicationUtils.h"
#import <QCAR/QCAR.h>
#import <QCAR/TrackerManager.h>
#import <QCAR/TextTracker.h>
#import <QCAR/VideoMode.h>
#import <QCAR/CameraDevice.h>


@interface TextRecoViewController ()

@end

@implementation TextRecoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
        // Custom initialization
        self.title = @"Text Reco";
        // Create the EAGLView with the screen dimensions
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        viewFrame = screenBounds;
        
        viewQCARFrame = viewFrame;
        
        // If this device has a retina display, scale the view bounds that will
        // be passed to QCAR; this allows it to calculate the size and position of
        // the viewport correctly when rendering the video background
        if (YES == vapp.isRetinaDisplay) {
            viewQCARFrame.size.width *= 2.0;
            viewQCARFrame.size.height *= 2.0;
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
    eaglView = [[TextRecoEAGLView alloc] initWithFrame:viewFrame appSession:vapp];
    [self setView:eaglView];
    SampleAppAppDelegate *appDelegate = (SampleAppAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = eaglView;
    
    // show loading animation while AR is being initialized
    [self showLoadingAnimation];
    
    // initialize the AR session
    [vapp initAR:QCAR::GL_20 ARViewBoundsSize:viewQCARFrame.size orientation:UIInterfaceOrientationPortrait];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self prepareMenu];

    self.navigationController.navigationBar.translucent = YES;

	// Do any additional setup after loading the view.
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)viewWillDisappear:(BOOL)animated {
    // cleanup menu
    [[SampleAppMenu instance]clear];

    self.navigationController.navigationBar.translucent = NO;
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

- (bool) doInitTrackers {
    // Initialize the image or marker tracker
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    
    // Image Tracker...
    QCAR::Tracker* trackerBase = trackerManager.initTracker(QCAR::TextTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Failed to initialize ImageTracker.");
        return NO;
    }
    NSLog(@"Successfully initialized ImageTracker.");
    return YES;
}

- (bool) doLoadTrackersData {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::TextTracker* textTracker = static_cast<QCAR::TextTracker*>(trackerManager.getTracker(QCAR::TextTracker::getClassType()));
    
    if (NULL != textTracker) {
        QCAR::WordList* wordList = textTracker->getWordList();
        NSString* wordListFile = @"Vuforia-English-word.vwl";
        // Load the word list
        if (false == wordList->loadWordList([wordListFile cStringUsingEncoding:NSASCIIStringEncoding], QCAR::STORAGE_APPRESOURCE)) {
            NSLog(@"failed to load word list");
            return NO;
        }
    }
    else {
        NSLog(@"failed to get TEXT_TRACKER");
        return NO;
    }
    return YES;
}

- (bool) doStartTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::TextTracker::getClassType());
    if (NULL != tracker) {
        if (true == tracker->start()) {
            NSLog(@"successfully started tracker");
        }
        else {
            NSLog(@"failed to start tracker");
            return NO;
        }
    }
    else {
        NSLog(@"failed to get the tracker from the tracker manager");
        return NO;
    }
    return YES;
}

- (void) prepareROI {
    // Get the default video mode
    QCAR::CameraDevice& cameraDevice = QCAR::CameraDevice::getInstance();
    QCAR::VideoMode videoMode = cameraDevice.getVideoMode(QCAR::CameraDevice::MODE_DEFAULT);
    
    // Text tracking region of interest
    int width = viewQCARFrame.size.width;
    int height = viewQCARFrame.size.height;
    
    QCAR::Vec2I loupeCenter(0, 0);
    QCAR::Vec2I loupeSize(0, 0);
    
    bool isIPad = NO;
    
    if (UIUserInterfaceIdiomPad == [[UIDevice currentDevice] userInterfaceIdiom]) {
        isIPad = YES;
    }
    
    // width of margin is:
    // 5% of the width of the screen for a phone
    // 20% of the width of the screen for a tablet
    int marginWidth = isIPad ? (width * 20) / 100 : (width * 5) / 100;
    
    // loupe height is:
    // 16% of the screen height for a phone
    // 10% of the screen height for a tablet
    int loupeHeight = isIPad ? (height * 10) / 100 : (height * 16) / 100;
    
    // lopue width takes the width of the screen minus 2 margins
    int loupeWidth = width - (2 * marginWidth);
    
    // Region of interest geometry
    ROICenterX = width / 2;
    ROICenterY = marginWidth + (loupeHeight / 2);
    ROIWidth = loupeWidth;
    ROIHeight = loupeHeight;
    
    // conversion to camera coordinates
    SampleApplicationUtils::screenCoordToCameraCoord(ROICenterX, ROICenterY, ROIWidth, ROIHeight,
                                          width, height, videoMode.mWidth, videoMode.mHeight,
                                          &loupeCenter.data[0], &loupeCenter.data[1], &loupeSize.data[0], &loupeSize.data[1]);
    
    [eaglView setRoiWidth:ROIWidth height:ROIHeight centerX:ROICenterX centerY:ROICenterY];
    
    QCAR::TextTracker* textTracker = (QCAR::TextTracker*)QCAR::TrackerManager::getInstance().getTracker(QCAR::TextTracker::getClassType());
    
    if (textTracker != 0)
    {
        QCAR::RectangleInt roi(loupeCenter.data[0] - loupeSize.data[0] / 2, loupeCenter.data[1] - loupeSize.data[1] / 2, loupeCenter.data[0] + loupeSize.data[0] / 2, loupeCenter.data[1] + loupeSize.data[1] / 2);
        textTracker->setRegionOfInterest(roi, roi, QCAR::TextTracker::REGIONOFINTEREST_UP_IS_9_HRS);
    }
}

- (void) onInitARDone:(NSError *)initError {
    [self hideLoadingAnimation];
    
    if (initError == nil) {
        NSError * error = nil;
        [vapp startAR:QCAR::CameraDevice::CAMERA_BACK error:&error];
                
        [self prepareROI];
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


- (bool) doStopTrackers {
    // Stop the tracker
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::TextTracker::getClassType());
    
    if (NULL == tracker) {
        NSLog(@"ERROR: failed to get the tracker from the tracker manager");
        return NO;
    }
    tracker->stop();
    NSLog(@"successfully stopped tracker");
    return YES;
}

- (bool) doUnloadTrackersData {
    return YES;
}

- (bool) doDeinitTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    trackerManager.deinitTracker(QCAR::TextTracker::getClassType());
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



#pragma mark - left menu

typedef enum {
    C_FLASH,
    C_CAMERA_FRONT,
    C_CAMERA_REAR
} MENU_COMMAND;

- (void) prepareMenu {
    
    SampleAppMenu * menu = [SampleAppMenu prepareWithCommandProtocol:self title:@"Text Reco"];
    SampleAppMenuGroup * group;
    
    group = [menu addGroup:@""];
    [group addTextItem:@"Vuforia Samples" command:-1];
    
    group = [menu addGroup:@""];
    [group addSelectionItem:@"Flash" command:C_FLASH isSelected:NO];
}

- (bool) menuProcess:(SampleAppMenu *) menu command:(int) command value:(bool) value{
    bool result = true;

    switch(command) {
        case C_FLASH:
            if (!QCAR::CameraDevice::getInstance().setFlashTorchMode(value)) {
                result = false;
            }
            break;
            
        default:
            result = false;
            break;
    }
    return result;
}


@end
