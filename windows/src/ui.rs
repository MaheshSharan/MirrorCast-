use eframe::egui;

/// UI state and theme management for the MirrorCast application.

#[derive(Debug, Clone, PartialEq)]
pub enum ConnectionState {
    Disconnected,
    WaitingForConnection,
    Connected,
}

/// Application theme configuration.
pub struct AppTheme {
    pub primary_color: egui::Color32,
    pub secondary_color: egui::Color32,
    pub background_color: egui::Color32,
    pub text_color: egui::Color32,
    pub accent_color: egui::Color32,
}

impl AppTheme {
    /// Create a dark theme for the application.
    pub fn dark() -> Self {
        Self {
            primary_color: egui::Color32::from_rgb(103, 80, 164),
            secondary_color: egui::Color32::from_rgb(98, 91, 113),
            background_color: egui::Color32::from_rgb(30, 30, 40),
            text_color: egui::Color32::WHITE,
            accent_color: egui::Color32::from_rgb(76, 175, 80),
        }
    }

    /// Create a light theme for the application.
    pub fn light() -> Self {
        Self {
            primary_color: egui::Color32::from_rgb(103, 80, 164),
            secondary_color: egui::Color32::from_rgb(98, 91, 113),
            background_color: egui::Color32::from_rgb(255, 255, 255),
            text_color: egui::Color32::BLACK,
            accent_color: egui::Color32::from_rgb(76, 175, 80),
        }
    }

    /// Apply this theme to the egui context.
    pub fn apply_to_context(&self, ctx: &egui::Context) {
        let mut style = (*ctx.style()).clone();
        
        style.visuals.override_text_color = Some(self.text_color);
        style.visuals.panel_fill = self.background_color;
        style.visuals.window_fill = self.background_color;
        style.visuals.extreme_bg_color = self.background_color;
        
        ctx.set_style(style);
    }
}

impl Default for AppTheme {
    fn default() -> Self {
        Self::dark()
    }
}
