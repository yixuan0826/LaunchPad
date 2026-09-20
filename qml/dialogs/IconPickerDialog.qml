import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

import "../components"

// Icon chooser for entries and categories.
//
// Tab 1 lists RinUI's Fluent glyphs (only names that exist in the bundled icon
// index are listed — an unknown name renders as blank).  Tab 2 lists the
// Lawnicons marks shipped under assets/icons/lawnicons.
QQC2.Dialog {
    id: picker

    property string current: ""

    signal picked(string iconKey)

    title: qsTr("选择图标")
    modal: true
    standardButtons: QQC2.Dialog.Cancel
    width: 640
    height: 560

    readonly property var fluentIcons: [
        "ic_fluent_home_20_regular", "ic_fluent_apps_20_regular", "ic_fluent_apps_list_20_regular",
        "ic_fluent_window_20_regular", "ic_fluent_window_new_20_regular", "ic_fluent_desktop_20_regular",
        "ic_fluent_laptop_20_regular", "ic_fluent_phone_20_regular", "ic_fluent_tablet_20_regular",
        "ic_fluent_folder_20_regular", "ic_fluent_folder_open_20_regular", "ic_fluent_folder_zip_20_regular",
        "ic_fluent_document_20_regular", "ic_fluent_document_text_20_regular", "ic_fluent_book_20_regular",
        "ic_fluent_code_20_regular", "ic_fluent_database_20_regular", "ic_fluent_server_20_regular",
        "ic_fluent_settings_20_regular", "ic_fluent_wrench_20_regular", "ic_fluent_toolbox_20_regular",
        "ic_fluent_search_20_regular", "ic_fluent_filter_20_regular", "ic_fluent_arrow_sort_20_regular",
        "ic_fluent_globe_20_regular", "ic_fluent_link_20_regular", "ic_fluent_link_square_20_regular",
        "ic_fluent_open_20_regular", "ic_fluent_arrow_import_20_regular", "ic_fluent_arrow_export_20_regular",
        "ic_fluent_arrow_download_20_regular", "ic_fluent_arrow_upload_20_regular",
        "ic_fluent_arrow_sync_20_regular", "ic_fluent_arrow_repeat_all_20_regular",
        "ic_fluent_play_20_regular", "ic_fluent_pause_20_regular", "ic_fluent_stop_20_regular",
        "ic_fluent_music_note_2_20_regular", "ic_fluent_headphones_20_regular", "ic_fluent_speaker_2_20_regular",
        "ic_fluent_image_20_regular", "ic_fluent_camera_20_regular", "ic_fluent_tv_20_regular",
        "ic_fluent_video_20_regular", "ic_fluent_paint_brush_20_regular", "ic_fluent_color_20_regular",
        "ic_fluent_text_font_20_regular", "ic_fluent_text_align_left_20_regular",
        "ic_fluent_pen_20_regular", "ic_fluent_edit_20_regular", "ic_fluent_copy_20_regular",
        "ic_fluent_save_20_regular", "ic_fluent_bookmark_20_regular", "ic_fluent_bookmark_multiple_20_regular",
        "ic_fluent_collections_20_regular", "ic_fluent_library_20_regular", "ic_fluent_list_20_regular",
        "ic_fluent_grid_20_regular", "ic_fluent_board_20_regular", "ic_fluent_panel_left_20_regular",
        "ic_fluent_split_horizontal_20_regular", "ic_fluent_box_multiple_20_regular",
        "ic_fluent_add_20_regular", "ic_fluent_delete_20_regular", "ic_fluent_dismiss_20_regular",
        "ic_fluent_checkmark_circle_20_regular", "ic_fluent_question_circle_20_regular",
        "ic_fluent_info_20_regular", "ic_fluent_star_20_regular", "ic_fluent_star_add_20_regular",
        "ic_fluent_rocket_20_regular", "ic_fluent_fire_20_regular", "ic_fluent_flash_20_regular",
        "ic_fluent_sparkle_20_regular", "ic_fluent_wand_20_regular", "ic_fluent_joystick_20_regular",
        "ic_fluent_puzzle_piece_20_regular", "ic_fluent_slide_text_20_regular",
        "ic_fluent_certificate_20_regular", "ic_fluent_shield_20_regular", "ic_fluent_shield_checkmark_20_regular",
        "ic_fluent_keyboard_20_regular", "ic_fluent_keyboard_123_20_regular", "ic_fluent_clock_20_regular",
        "ic_fluent_pin_20_regular", "ic_fluent_map_pin_20_regular", "ic_fluent_note_pin_20_regular",
        "ic_fluent_person_20_regular", "ic_fluent_people_20_regular", "ic_fluent_eye_20_regular",
        "ic_fluent_eye_off_20_regular", "ic_fluent_data_usage_20_regular", "ic_fluent_ribbon_20_regular",
        "ic_fluent_broom_20_regular", "ic_fluent_power_20_regular", "ic_fluent_print_20_regular",
        "ic_fluent_calculator_20_regular", "ic_fluent_food_20_regular", "ic_fluent_drop_20_regular",
        "ic_fluent_arrow_reset_20_regular", "ic_fluent_reorder_20_regular",
        "ic_fluent_more_horizontal_20_regular", "ic_fluent_more_vertical_20_regular",
        "ic_fluent_arrow_up_20_regular", "ic_fluent_arrow_down_20_regular",
        "ic_fluent_arrow_left_20_regular", "ic_fluent_arrow_right_20_regular"
    ]

    property var bundledIcons: []

    readonly property var activeIcons: tabs.currentIndex === 0 ? fluentIcons : bundledIcons

    onAboutToShow: {
        bundledIcons = ConfigManager.getBundledIcons().map(
            function (name) { return "lawnicons:" + name })
        tabs.currentIndex = current.indexOf("lawnicons:") === 0 && bundledIcons.length > 0 ? 1 : 0
    }

    TabBar {
        id: tabs
        width: parent.width
        TabButton { text: qsTr("Fluent 图标") }
        TabButton { text: qsTr("Lawnicons") }
    }

    GridView {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        cellWidth: 52
        cellHeight: 52
        model: picker.activeIcons

        delegate: ToolButton {
            width: 52
            height: 52
            checkable: true
            checked: picker.current === modelData
            onClicked: {
                picker.picked(modelData)
                picker.close()
            }

            AppIcon {
                anchors.centerIn: parent
                iconKey: modelData
                iconSize: 24
            }
        }
    }
}
