﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Euler : MonoBehaviour
{
    public RenderTexture DyeRT;
    public RenderTexture DyeRT2;
    public RenderTexture VelocityRT;
    public RenderTexture VelocityRT2;
    public RenderTexture DivergenceRT;
    public RenderTexture PressureRT;
    public RenderTexture PressureRT2;

    public Material InitDyeMat;
    public Material InitVelocityMat;
    public Material AdvectionMat;
    public Material SplatMat;
    public Material DivergenceMat;
    public Material PressureMat;
    public Material SubtractMat;
    public Material DisplayMat;

    double MouseX = 0, MouseY = 0, MouseDX = 0, MouseDY = 0;
    int  TexWidth = 512, TexHeight = 512;
    int MouseDown = 0;
    void Start()
    {
        DivergenceRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); DivergenceRT.Create();
        DyeRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); DyeRT.Create();
        DyeRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.ARGBHalf); DyeRT2.Create();
        VelocityRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); VelocityRT.Create();
        VelocityRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); VelocityRT2.Create();
        PressureRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); PressureRT.Create();
        PressureRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); PressureRT2.Create();

        Graphics.Blit(null,DyeRT,InitDyeMat);
        Graphics.Blit(null, VelocityRT, InitVelocityMat);
        Graphics.Blit(null, PressureRT);
    }

    void Update()
    {
        if (Input.GetMouseButtonDown(0)) MouseDown = 1;
        if (Input.GetMouseButtonUp(0)) MouseDown = 0;

        MouseDX = Input.mousePosition.x - MouseX;
        MouseDY = Input.mousePosition.y - MouseY;
        MouseX = Input.mousePosition.x;
        MouseY = Input.mousePosition.y;
    }
    void Prepare()
    {

        //第一步：平流速度
         Graphics.Blit(VelocityRT, VelocityRT2);
        AdvectionMat.SetTexture("_VelocityTex", VelocityRT2);
        Graphics.Blit(VelocityRT2, VelocityRT, AdvectionMat);
        
        //第二步：添加鼠标拖动的力，得到中间速度
        SplatMat.SetTexture("_VelocityTex", VelocityRT);
        SplatMat.SetFloat("PointerX", (float)MouseX / Screen.width);
        SplatMat.SetFloat("PointerY", (float)MouseY / Screen.height);
        SplatMat.SetFloat("PointerDX", (float)MouseDX / Screen.width);
        SplatMat.SetFloat("PointerDY", (float)MouseDY / Screen.height);
        SplatMat.SetInt("MouseDown", MouseDown);
        Graphics.Blit(null, VelocityRT2, SplatMat);

        //第三步：根据中间速度算出散度
        DivergenceMat.SetTexture("_VelocityTex", VelocityRT2);
        Graphics.Blit(VelocityRT2, DivergenceRT, DivergenceMat);

        //第四步：根据散度和中间速度，迭代计算压力
        PressureMat.SetTexture("_DivergenceTex", DivergenceRT);
        for (int i = 0; i < 20; i++)
        {
            Graphics.Blit(PressureRT, PressureRT2);
            PressureMat.SetTexture("_PressureTex", PressureRT2);
            Graphics.Blit(DivergenceRT, PressureRT, PressureMat);
        }

        //第五步：中间速度减去压力梯度，得无散度的下一时刻速度
        SubtractMat.SetTexture("_VelocityTex", VelocityRT2);
        SubtractMat.SetTexture("_PressureTex", PressureRT);
        Graphics.Blit(VelocityRT2, VelocityRT, SubtractMat);

        //第六步：用最终速度平流颜色
        Graphics.Blit(DyeRT, DyeRT2);
        DisplayMat.SetTexture("_DyeTex", DyeRT2);
        DisplayMat.SetTexture("_VelocityTex", VelocityRT);
        Graphics.Blit(DyeRT2, DyeRT, DisplayMat);
    }
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Prepare();
        //试一下把DyeRT改成VelocityRT/DivergenceRT/PressureRT会出现什么？
        Graphics.Blit(DyeRT, destination);
       // Graphics.Blit(DivergenceRT, destination);
    }
}
