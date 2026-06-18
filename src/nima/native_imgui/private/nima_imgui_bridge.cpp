#include "imgui/imgui.h"

extern "C" bool Nima_ImGui_WantCaptureMouse() {
  return ImGui::GetIO().WantCaptureMouse;
}

extern "C" bool Nima_ImGui_WantCaptureKeyboard() {
  return ImGui::GetIO().WantCaptureKeyboard;
}

extern "C" void Nima_ImGui_SetIniFilename(const char* path) {
  ImGui::GetIO().IniFilename = path;
}

extern "C" void Nima_ImGui_SetDisplayScale(float x, float y) {
  ImGui::GetIO().DisplayFramebufferScale = ImVec2(x, y);
}

extern "C" void Nima_ImGui_SetNavigation(bool keyboard, bool gamepad) {
  ImGuiIO& io = ImGui::GetIO();
  if (keyboard) {
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
  } else {
    io.ConfigFlags &= ~ImGuiConfigFlags_NavEnableKeyboard;
  }
  if (gamepad) {
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
  } else {
    io.ConfigFlags &= ~ImGuiConfigFlags_NavEnableGamepad;
  }
}

extern "C" void Nima_ImGui_SetDocking(bool enabled) {
  ImGuiIO& io = ImGui::GetIO();
  if (enabled) {
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
  } else {
    io.ConfigFlags &= ~ImGuiConfigFlags_DockingEnable;
  }
}
