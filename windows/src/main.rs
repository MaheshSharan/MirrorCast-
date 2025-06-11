use anyhow::Result;
use eframe::egui;

mod app;
mod qr;
mod webrtc;
mod renderer;
mod ui;

use app::MirrorCastApp;

/// Main entry point for the MirrorCast Windows application.
fn main() -> Result<()> {
    // Initialize logging
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Info)
        .init();

    log::info!("Starting MirrorCast Windows application");

    // Configure the native application options
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([800.0, 600.0])
            .with_min_inner_size([600.0, 400.0])
            .with_title("MirrorCast - Wireless Screen Mirroring")
            .with_icon(load_icon()),
        ..Default::default()
    };

    // Start the application
    eframe::run_native(
        "MirrorCast",
        options,
        Box::new(|cc| {
            // Configure egui styling
            setup_custom_style(&cc.egui_ctx);
            
            // Return the app instance
            Box::new(MirrorCastApp::new(cc))
        }),
    )
    .map_err(|e| anyhow::anyhow!("Failed to run application: {}", e))
}

/// Load the application icon.
fn load_icon() -> egui::IconData {
    // For now, return a default icon
    // Future: Add custom MirrorCast icon
    egui::IconData::default()
}

/// Setup custom styling for the application.
fn setup_custom_style(ctx: &egui::Context) {
    let mut style = (*ctx.style()).clone();
    
    // Customize colors
    style.visuals.override_text_color = Some(egui::Color32::WHITE);
    style.visuals.panel_fill = egui::Color32::from_rgb(30, 30, 40);
    style.visuals.window_fill = egui::Color32::from_rgb(25, 25, 35);
    style.visuals.extreme_bg_color = egui::Color32::from_rgb(15, 15, 20);
    
    // Customize spacing
    style.spacing.item_spacing = egui::vec2(8.0, 8.0);
    style.spacing.button_padding = egui::vec2(12.0, 8.0);
    style.spacing.window_margin = egui::style::Margin::same(16.0);
    
    // Apply the style
    ctx.set_style(style);
    
    log::debug!("Custom styling applied");
}
