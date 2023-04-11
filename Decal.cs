using UnityEngine;
using UnityEditor;

using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class Decal : MonoBehaviour
{
    public Material m_Material;
    public Texture2D texture;
    public Color tinting = Color.white;
    [SerializeField]
    Camera cam;
    public Mesh m_CubeMesh;
    MaterialPropertyBlock props;

    public void OnEnable()
    {
        props = new MaterialPropertyBlock();
    }

    void LateUpdate()
    {
        // drawing to all cameras, but you can set it to just a specific one here
        Draw(cam);
    }


    private void Draw(Camera camera)
    {

        // set up property block for decal texture and tinting
        if (texture != null)
        {
            props.SetTexture("_MainTex", texture);
        }
        props.SetColor("_Tint", tinting);
        // draw the decal on the main camera
        Graphics.DrawMesh(m_CubeMesh, transform.localToWorldMatrix, m_Material, 0, null, 0, props, false, true, false);


    }
}