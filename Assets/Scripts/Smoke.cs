using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Smoke : MonoBehaviour
{
    public Material smokeMat;
    public Color color;
    private RenderTexture DivergenceRT;
    private RenderTexture CurlRT;
    private RenderTexture DensityRT;
    private RenderTexture DensityRT2;
    private RenderTexture VelocityRT;
    private RenderTexture VelocityRT2;
    private RenderTexture PressureRT;
    private RenderTexture PressureRT2;

    [Range(0.95f, 1.0f)]
    public float DensityDiffusion = 0.995f;//密度消失速度，此值越大则粘度越小，越容易看到烟雾效果
    [Range(0.95f, 1.0f)]
    public float VelocityDiffusion = 0.995f;//速度扩散速度，此值越大则粘度越小，越容易看到烟雾效果
    [Range(1, 60)]
    public int Iterations = 50;//泊松方程迭代次数
    [Range(0, 60)]
    public float Vorticity = 50f;//控制漩涡缩放
    [Range(0.0001f, 0.005f)]
    public float SplatRadius = 0.001f;//鼠标点击产生烟雾的半径
    [Range(1, 15)]
    public float MouseForceScale = 10.0f;//鼠标拖动力度缩放

    private float dt = 0.01f;
    private float MouseDX = 0.0f, MouseDY = 0.0f, MouseX, MouseY;

    void Start()
    {
        int TexWidth = Screen.width;
        int TexHeight = Screen.height;
        DivergenceRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); DivergenceRT.Create();
        CurlRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); CurlRT.Create();
        DensityRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.ARGBHalf); DensityRT.Create();
        DensityRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.ARGBHalf); DensityRT2.Create();
        VelocityRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); VelocityRT.Create();
        
        VelocityRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RGHalf); VelocityRT2.Create();
        PressureRT = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); PressureRT.Create();
        PressureRT2 = new RenderTexture(TexWidth, TexHeight, 0, RenderTextureFormat.RHalf); PressureRT2.Create();
        
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {

        //鼠标输入相关
        MouseDX = (Input.mousePosition.x - MouseX) * MouseForceScale;
        MouseDY = (Input.mousePosition.y - MouseY) * MouseForceScale;
        MouseX = Input.mousePosition.x;
        MouseY = Input.mousePosition.y;

        //第一步：平流速度
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        smokeMat.SetTexture("VelocityDensityTex", VelocityRT2);
        smokeMat.SetFloat("dt", dt);
        smokeMat.SetFloat("dissipation", VelocityDiffusion);
        Graphics.Blit(VelocityRT2, VelocityRT, smokeMat, 0);
        Graphics.Blit(VelocityRT, VelocityRT2);

        if (Input.GetMouseButton(0))
        {
            //第二步：鼠标拖动会影响速度
            smokeMat.SetTexture("VelocityDensityTex", VelocityRT2);
            smokeMat.SetVector("color", new Vector3(MouseDX, MouseDY, 1f));
            smokeMat.SetVector("pointerpos", new Vector2(MouseX, MouseY));
            smokeMat.SetFloat("radius", SplatRadius);
            smokeMat.SetFloat("isColor", 0);
            Graphics.Blit(VelocityRT2, VelocityRT, smokeMat, 1);
            Graphics.Blit(VelocityRT, VelocityRT2);

            //第三步：鼠标拖动也会影响密度
            smokeMat.SetTexture("VelocityDensityTex", DensityRT2);
            smokeMat.SetVector("color", color);
            smokeMat.SetFloat("isColor", 0);
            Graphics.Blit(DensityRT2, DensityRT, smokeMat, 1);
            Graphics.Blit(DensityRT, DensityRT2);
        }

        //第四步：计算Curl
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        Graphics.Blit(VelocityRT2, CurlRT, smokeMat, 2);

        //第五步：计算旋度，更新速度，得到有散度的速度场
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        smokeMat.SetTexture("CurlTex", CurlRT);
        smokeMat.SetFloat("curl", Vorticity);
        smokeMat.SetFloat("dt", dt);
        Graphics.Blit(VelocityRT2, VelocityRT, smokeMat, 3);
        Graphics.Blit(VelocityRT, VelocityRT2);

        //第六步：计算散度
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        Graphics.Blit(VelocityRT2, DivergenceRT, smokeMat, 4);

        //第七步：计算压力
        smokeMat.SetTexture("DivergenceTex", DivergenceRT);
        for (int i = 0; i < Iterations; i++)
        {
            smokeMat.SetTexture("PressureTex", PressureRT2);
            Graphics.Blit(PressureRT2, PressureRT, smokeMat, 5);
            Graphics.Blit(PressureRT, PressureRT2);
        }

        //第八步：速度场减去压力梯度，得到无散度的速度场
        smokeMat.SetTexture("PressureTex", PressureRT2);
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        Graphics.Blit(VelocityRT2, VelocityRT, smokeMat, 6);
        Graphics.Blit(VelocityRT, VelocityRT2);

        //第九步：用最终速度去平流密度
        smokeMat.SetTexture("VelocityTex", VelocityRT2);
        smokeMat.SetTexture("VelocityDensityTex", DensityRT2);
        smokeMat.SetFloat("dissipation", DensityDiffusion);
        Graphics.Blit(DensityRT2, DensityRT, smokeMat, 0);
        Graphics.Blit(DensityRT, DensityRT2);

        //第十步：显示
        Graphics.Blit(DensityRT, destination);
    }
}

