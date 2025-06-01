using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightManager : MonoBehaviour
{
    public Light mianLight;
    
    public static LightManager instance;

    private void OnValidate()
    {
        if(instance == null)
            instance = this;
    }

    void Awake()
    {
        if(instance != null)
            Destroy(instance);
        instance = this;
    }

    public Light GetMainLight()
    {
        return mianLight;
    }
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
