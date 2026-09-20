import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

// Shared Fluent icon chooser.
//
// Set `targetButton` to the ToolButton whose `icon.name` should be replaced,
// then call open().  Both the action and the category editors use this single
// instance instead of each keeping its own copy of the icon list.
QQC2.Dialog {
    id: iconPicker

    property var targetButton: null

    readonly property var iconGroups: [
        [
            "ic_fluent_rocket_20_regular", "ic_fluent_star_20_regular", "ic_fluent_folder_20_regular",
            "ic_fluent_file_20_regular", "ic_fluent_code_20_regular", "ic_fluent_terminal_20_regular",
            "ic_fluent_database_20_regular", "ic_fluent_server_20_regular", "ic_fluent_cloud_20_regular",
            "ic_fluent_globe_20_regular", "ic_fluent_play_20_regular", "ic_fluent_pause_20_regular",
            "ic_fluent_stop_20_regular", "ic_fluent_forward_20_regular", "ic_fluent_back_20_regular",
            "ic_fluent_volume_2_20_regular", "ic_fluent_volume_mute_20_regular", "ic_fluent_image_20_regular",
            "ic_fluent_video_20_regular", "ic_fluent_music_note_20_regular", "ic_fluent_game_20_regular",
            "ic_fluent_tv_20_regular", "ic_fluent_phone_20_regular", "ic_fluent_tablet_20_regular",
            "ic_fluent_laptop_20_regular", "ic_fluent_desktop_20_regular", "ic_fluent_keyboard_20_regular",
            "ic_fluent_mouse_20_regular", "ic_fluent_print_20_regular", "ic_fluent_camera_20_regular",
            "ic_fluent_settings_20_regular", "ic_fluent_toolbox_20_regular", "ic_fluent_wrench_20_regular",
            "ic_fluent_hammer_20_regular", "ic_fluent_pen_20_regular", "ic_fluent_pencil_20_regular",
            "ic_fluent_paint_brush_20_regular", "ic_fluent_palette_20_regular", "ic_fluent_magic_wand_20_regular",
            "ic_fluent_fire_20_regular", "ic_fluent_bolt_20_regular", "ic_fluent_leaf_20_regular",
            "ic_fluent_tree_20_regular", "ic_fluent_sprout_20_regular", "ic_fluent_sun_20_regular",
            "ic_fluent_moon_20_regular", "ic_fluent_cloud_sun_20_regular", "ic_fluent_cloud_moon_20_regular",
            "ic_fluent_drop_20_regular", "ic_fluent_wind_20_regular"
        ],
        [
            "ic_fluent_shopping_cart_20_regular", "ic_fluent_cart_20_regular", "ic_fluent_bag_20_regular",
            "ic_fluent_gift_20_regular", "ic_fluent_box_20_regular", "ic_fluent_package_20_regular",
            "ic_fluent_tag_20_regular", "ic_fluent_barcode_20_regular", "ic_fluent_qrcode_20_regular",
            "ic_fluent_receipt_20_regular", "ic_fluent_credit_card_20_regular", "ic_fluent_calculator_20_regular",
            "ic_fluent_chart_20_regular", "ic_fluent_pie_chart_20_regular", "ic_fluent_bar_chart_20_regular",
            "ic_fluent_line_chart_20_regular", "ic_fluent_area_chart_20_regular", "ic_fluent_scatter_chart_20_regular",
            "ic_fluent_bubble_chart_20_regular", "ic_fluent_radar_chart_20_regular", "ic_fluent_funnel_chart_20_regular",
            "ic_fluent_gantt_chart_20_regular", "ic_fluent_org_chart_20_regular", "ic_fluent_sunburst_20_regular",
            "ic_fluent_waterfall_20_regular", "ic_fluent_stock_20_regular", "ic_fluent_candlestick_20_regular"
        ]
    ]

    title: qsTr("选择图标")
    modal: true
    standardButtons: QQC2.Dialog.Cancel
    width: 560
    height: 480

    TabBar {
        id: tabBar
        width: parent.width
        TabButton { text: qsTr("Fluent Icons") }
        TabButton { text: qsTr("More Icons") }
    }

    GridView {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        cellWidth: 48
        cellHeight: 48
        model: iconPicker.iconGroups[tabBar.currentIndex]

        delegate: ToolButton {
            width: 48
            height: 48
            icon.name: modelData
            checkable: true
            checked: iconPicker.targetButton
                && iconPicker.targetButton.icon.name === modelData
            onClicked: {
                if (iconPicker.targetButton) {
                    iconPicker.targetButton.icon.name = modelData
                }
                iconPicker.close()
            }
        }
    }

    onAboutToShow: tabBar.currentIndex = 0
}
