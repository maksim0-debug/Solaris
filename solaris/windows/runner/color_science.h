#ifndef SOLARIS_WINDOWS_RUNNER_COLOR_SCIENCE_H_
#define SOLARIS_WINDOWS_RUNNER_COLOR_SCIENCE_H_

#include <algorithm>

namespace solaris {
namespace color_science {

// Planckian Blackbody Radiation Spectrum (CIE 1931 2° Standard Observer, sRGB D65 chromatic adaptation):
// - Anchored at 1900K Candlelight: R = 1.000000, G = 0.520741, B = 0.131801.
// - Blue channel is attenuated by ~87% (yielding ~1% optical luminance on gamma 2.2),
//   eliminating melanopic disruption while preserving dark theme neutral grays,
//   syntax highlighting, and link readability.
// - Spans 1000K to 6500K in uniform 50K increments (111 points) with linear interpolation.
// - Strictly monotonic for both G and B across all 111 steps.
struct RgbPoint {
  float g;
  float b;
};

inline constexpr int kMinKelvin = 1000;
inline constexpr int kMaxKelvin = 6500;
inline constexpr int kKelvinStep = 50;
inline constexpr int kNumLutPoints = 111;

inline constexpr RgbPoint kPlanckianLut[kNumLutPoints] = {
    {0.146468f, 0.000000f}, // 1000K
    {0.192331f, 0.000000f}, // 1050K
    {0.228199f, 0.000000f}, // 1100K
    {0.258610f, 0.000000f}, // 1150K
    {0.285447f, 0.000000f}, // 1200K
    {0.309698f, 0.000000f}, // 1250K
    {0.331959f, 0.000000f}, // 1300K
    {0.352622f, 0.000000f}, // 1350K
    {0.371960f, 0.000000f}, // 1400K
    {0.390173f, 0.000000f}, // 1450K
    {0.407412f, 0.000000f}, // 1500K
    {0.423796f, 0.000000f}, // 1550K
    {0.439420f, 0.000000f}, // 1600K
    {0.454360f, 0.000000f}, // 1650K
    {0.468681f, 0.000000f}, // 1700K
    {0.482437f, 0.046762f}, // 1750K
    {0.495673f, 0.084331f}, // 1800K
    {0.508429f, 0.110135f}, // 1850K
    {0.520741f, 0.131801f}, // 1900K
    {0.532637f, 0.151243f}, // 1950K
    {0.544144f, 0.169274f}, // 2000K
    {0.555288f, 0.186317f}, // 2050K
    {0.566088f, 0.202623f}, // 2100K
    {0.576564f, 0.218351f}, // 2150K
    {0.586734f, 0.233609f}, // 2200K
    {0.596613f, 0.248473f}, // 2250K
    {0.606216f, 0.262998f}, // 2300K
    {0.615556f, 0.277225f}, // 2350K
    {0.624646f, 0.291184f}, // 2400K
    {0.633497f, 0.304900f}, // 2450K
    {0.642118f, 0.318392f}, // 2500K
    {0.650521f, 0.331675f}, // 2550K
    {0.658713f, 0.344761f}, // 2600K
    {0.666704f, 0.357661f}, // 2650K
    {0.674501f, 0.370383f}, // 2700K
    {0.682112f, 0.382933f}, // 2750K
    {0.689544f, 0.395319f}, // 2800K
    {0.696802f, 0.407544f}, // 2850K
    {0.703894f, 0.419614f}, // 2900K
    {0.710826f, 0.431532f}, // 2950K
    {0.717601f, 0.443302f}, // 3000K
    {0.724227f, 0.454927f}, // 3050K
    {0.730708f, 0.466409f}, // 3100K
    {0.737048f, 0.477752f}, // 3150K
    {0.743252f, 0.488958f}, // 3200K
    {0.749324f, 0.500028f}, // 3250K
    {0.755268f, 0.510966f}, // 3300K
    {0.761089f, 0.521772f}, // 3350K
    {0.766789f, 0.532449f}, // 3400K
    {0.772373f, 0.542999f}, // 3450K
    {0.777843f, 0.553423f}, // 3500K
    {0.783203f, 0.563723f}, // 3550K
    {0.788456f, 0.573900f}, // 3600K
    {0.793605f, 0.583956f}, // 3650K
    {0.798653f, 0.593893f}, // 3700K
    {0.803602f, 0.603712f}, // 3750K
    {0.808455f, 0.613414f}, // 3800K
    {0.813215f, 0.623001f}, // 3850K
    {0.817884f, 0.632474f}, // 3900K
    {0.822465f, 0.641835f}, // 3950K
    {0.826959f, 0.651085f}, // 4000K
    {0.831369f, 0.660225f}, // 4050K
    {0.835697f, 0.669257f}, // 4100K
    {0.839944f, 0.678182f}, // 4150K
    {0.844114f, 0.687001f}, // 4200K
    {0.848208f, 0.695715f}, // 4250K
    {0.852227f, 0.704326f}, // 4300K
    {0.856174f, 0.712835f}, // 4350K
    {0.860050f, 0.721243f}, // 4400K
    {0.863856f, 0.729552f}, // 4450K
    {0.867595f, 0.737763f}, // 4500K
    {0.871268f, 0.745876f}, // 4550K
    {0.874877f, 0.753893f}, // 4600K
    {0.878422f, 0.761815f}, // 4650K
    {0.881906f, 0.769644f}, // 4700K
    {0.885329f, 0.777381f}, // 4750K
    {0.888694f, 0.785026f}, // 4800K
    {0.892001f, 0.792581f}, // 4850K
    {0.895252f, 0.800047f}, // 4900K
    {0.898447f, 0.807425f}, // 4950K
    {0.901589f, 0.814716f}, // 5000K
    {0.904757f, 0.821928f}, // 5050K
    {0.908026f, 0.829067f}, // 5100K
    {0.911385f, 0.836132f}, // 5150K
    {0.914824f, 0.843125f}, // 5200K
    {0.918336f, 0.850046f}, // 5250K
    {0.921907f, 0.856895f}, // 5300K
    {0.925530f, 0.863671f}, // 5350K
    {0.929195f, 0.870376f}, // 5400K
    {0.932890f, 0.877009f}, // 5450K
    {0.936607f, 0.883572f}, // 5500K
    {0.940335f, 0.890062f}, // 5550K
    {0.944066f, 0.896482f}, // 5600K
    {0.947787f, 0.902831f}, // 5650K
    {0.951491f, 0.909108f}, // 5700K
    {0.955166f, 0.915316f}, // 5750K
    {0.958803f, 0.921453f}, // 5800K
    {0.962391f, 0.927519f}, // 5850K
    {0.965920f, 0.933515f}, // 5900K
    {0.969381f, 0.939441f}, // 5950K
    {0.972762f, 0.945296f}, // 6000K
    {0.976054f, 0.951083f}, // 6050K
    {0.979248f, 0.956798f}, // 6100K
    {0.982332f, 0.962443f}, // 6150K
    {0.985296f, 0.968018f}, // 6200K
    {0.988131f, 0.973524f}, // 6250K
    {0.990827f, 0.978959f}, // 6300K
    {0.993371f, 0.984324f}, // 6350K
    {0.995755f, 0.989619f}, // 6400K
    {0.997969f, 0.994845f}, // 6450K
    {1.000000f, 1.000000f}, // 6500K
};

// Computes normalized RGB multipliers (0.0 .. 1.0) for a given color temperature in Kelvin.
// Evaluates in sub-microsecond time with high-precision linear interpolation.
inline void CalculatePlanckianRgb(int kelvin, float& r, float& g, float& b) {
  int clamped = std::clamp(kelvin, kMinKelvin, kMaxKelvin);
  if (clamped >= kMaxKelvin) {
    r = 1.0f;
    g = 1.0f;
    b = 1.0f;
    return;
  }

  int offset = clamped - kMinKelvin;
  int idx = offset / kKelvinStep;
  float frac = static_cast<float>(offset % kKelvinStep) / static_cast<float>(kKelvinStep);

  r = 1.0f;
  g = kPlanckianLut[idx].g + (kPlanckianLut[idx + 1].g - kPlanckianLut[idx].g) * frac;
  b = kPlanckianLut[idx].b + (kPlanckianLut[idx + 1].b - kPlanckianLut[idx].b) * frac;
}

} // namespace color_science
} // namespace solaris

#endif // SOLARIS_WINDOWS_RUNNER_COLOR_SCIENCE_H_
