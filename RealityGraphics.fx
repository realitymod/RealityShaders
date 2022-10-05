
/*
	Third-party shader code
*/

#if !defined(REALITYGRAPHICS_FX)
	#define REALITYGRAPHICS_FX

	// Converts linear depth to logarithmic depth in the vertex shader
	// Source: https://outerra.blogspot.com/2013/07/logarithmic-depth-buffer-optimizations.html
	float4 GetLogarithmicDepth(float4 HPos)
	{
		const float FarPlane = 1000.0;
		float FCoef = 2.0 / log2(FarPlane + 1.0);
		HPos.z = log2(max(1e-6, 1.0 + HPos.w)) * FCoef - 1.0;
		return HPos;
	}

	/*
		Source: https://github.com/microsoft/DirectX-Graphics-Samples

		The MIT License (MIT)

		Copyright (c) 2015 Microsoft

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	*/

	float3 ApplySRGBCurve(float3 x)
	{
		float3 c = (x < 0.0031308) ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
		return c;
	}

	float3 RemoveSRGBCurve(float3 x)
	{
		float3 c = (x < 0.04045) ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
		return c;
	}
#endif
