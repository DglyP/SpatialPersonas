using System.Collections;
using System.Runtime.InteropServices;
using System;
using AOT;
using UnityEngine;
using UnityEngine.UI;

public class SpatialPersonaManager : MonoBehaviour
{
    public static SpatialPersonaManager Instance { get; private set; }
    public Button startSharePlayButton;
    public Button stopSharePlayButton;
    
    void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(this.gameObject); }
        else { Instance = this; DontDestroyOnLoad(this.gameObject); }
    }

    void Start()
    {
        startSharePlayButton.onClick.AddListener(PrepareSession);
        stopSharePlayButton.onClick.AddListener(EndSession);

#if (UNITY_VISIONOS || UNITY_IOS) && !UNITY_EDITOR

        return;
#endif

    }

    private void OnMessageReceived(string msg)
    {
    }

#if (UNITY_VISIONOS || UNITY_IOS) && !UNITY_EDITOR
    // real code on device will call Obj-C and Swift codes here instead
#else

    void PrepareSession()
    {
        //Debug.Log("Start Group Activity"); // handleStartGroupActivity
        //Debug.Log("The button is working -----------------------");
    }

    void EndSession()
    {
        //Debug.Log("End Group Activity"); // handleEndGroupActivity
    }

#endif
    
    bool IsVisionOs()
    {
        #if UNITY_VISIONOS && !UNITY_EDITOR
            return true;
        #endif
            return false;
    }


#if (UNITY_VISIONOS || UNITY_IOS) && !UNITY_EDITOR

    [DllImport("__Internal")]
    static extern void PrepareSession();
    [DllImport("__Internal")]
    static extern void EndSession();

#else

#endif

    private void FixedUpdate()
    {
#if UNITY_IOS || UNITY_VISIONOS && !UNITY_EDITOR
        // Continuously request latest variables
        // (done this way since we must await UnitySendMessage
        // from Swift, which OnMessageReceived picks up)
#endif
    }

}
