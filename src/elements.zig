//! zapui elements module
//! Re-exports all element types and builder functions

pub const div = @import("elements/div.zig");
pub const text = @import("elements/text.zig");
pub const button = @import("elements/button.zig");
pub const checkbox = @import("elements/checkbox.zig");
pub const slider = @import("elements/slider.zig");
pub const badge = @import("elements/badge.zig");
pub const card = @import("elements/card.zig");
pub const divider = @import("elements/divider.zig");
pub const tabs = @import("elements/tabs.zig");
pub const input = @import("elements/input.zig");
pub const toggle = @import("elements/toggle.zig");
pub const progress = @import("elements/progress.zig");
pub const avatar = @import("elements/avatar.zig");

// Re-export element types
pub const Div = div.Div;
pub const Text = text.Text;
pub const Button = button.Button;
pub const Checkbox = checkbox.Checkbox;
pub const Slider = slider.Slider;
pub const Badge = badge.Badge;
pub const Card = card.Card;
pub const Divider = divider.Divider;
pub const Tabs = tabs.Tabs;
pub const Input = input.Input;
pub const Toggle = toggle.Toggle;
pub const Progress = progress.Progress;
pub const Avatar = avatar.Avatar;
