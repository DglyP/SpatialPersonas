#import <UnityFramework/UnityFramework-Swift.h>

extern "C"
{
       ///
       /// SharePlay action functions with new model
       ///
   
       void PrepareSession()
       {
           [[SwiftToUnity shared]   prepareSession];
       }
   
       void EndSession()
       {
           [[SwiftToUnity shared]   endSession];
       }

}
