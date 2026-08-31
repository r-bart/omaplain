import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]


def _rgb(value: str) -> tuple[float, float, float]:
    return tuple(int(value[index:index + 2], 16) / 255 for index in (1, 3, 5))


def _luminance(color: tuple[float, float, float]) -> float:
    channels = [
        channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
        for channel in color
    ]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def _contrast_with_alpha(foreground: str, background: str, alpha: float) -> float:
    fg = _rgb(foreground)
    bg = _rgb(background)
    composite = tuple(fg[index] * alpha + bg[index] * (1 - alpha) for index in range(3))
    light, dark = sorted((_luminance(composite), _luminance(bg)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


class UiContractTests(unittest.TestCase):
    def test_secondary_text_alpha_passes_reference_palettes(self) -> None:
        palettes = {
            "nightcall": ("#ddd9ef", "#090a16"),
            "periphery": ("#a9c0bf", "#060f12"),
            "dawn": ("#2b2620", "#f4ece0"),
            "quattrocento-light": ("#33291b", "#f0e6d3"),
        }
        for name, (foreground, background) in palettes.items():
            with self.subTest(theme=name):
                self.assertGreaterEqual(_contrast_with_alpha(foreground, background, 0.68), 4.5)

    def test_known_low_contrast_text_opacities_do_not_return(self) -> None:
        files = [
            REPO / "Panel.qml",
            REPO / "components" / "WelcomePage.qml",
            REPO / "components" / "TourPage.qml",
            REPO / "components" / "ExcludedAppRow.qml",
            REPO / "components" / "EmptyState.qml",
        ]
        low_contrast = re.compile(r"Util\.alpha\(Color\.popups\.text, 0\.(?:58|62|66)\)")
        for path in files:
            with self.subTest(file=path.name):
                self.assertIsNone(low_contrast.search(path.read_text(encoding="utf-8")))

    def test_controls_scale_the_minimum_hit_height(self) -> None:
        files = [REPO / "Panel.qml", *sorted((REPO / "components").glob("*.qml"))]
        raw_height = re.compile(r"(?:implicitHeight:\s*44\b|Math\.max\(44\b)")
        for path in files:
            with self.subTest(file=path.name):
                self.assertIsNone(raw_height.search(path.read_text(encoding="utf-8")))

    def test_internal_view_changes_do_not_wait_for_open_timer(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        handler = re.search(r"onViewModeChanged:\s*\{(?P<body>.*?)\n\s*\}", panel, re.DOTALL)
        self.assertIsNotNone(handler)
        self.assertIn("Qt.callLater(root.applyViewFocus)", handler.group("body"))
        self.assertNotIn("initialFocusTimer.restart()", handler.group("body"))

    def test_welcome_cards_share_a_multicolumn_height(self) -> None:
        welcome = (REPO / "components" / "WelcomePage.qml").read_text(encoding="utf-8")
        self.assertIn("features.columns === 1", welcome)
        self.assertIn(": Style.space(108)", welcome)

    def test_exclusions_render_an_empty_state_only_while_both_lists_are_empty(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        block = re.search(r"EmptyState \{(?P<body>.*?)\n\s{12}\}", panel, re.DOTALL)
        self.assertIsNotNone(block, "el panel ya no monta un EmptyState")
        body = block.group("body")
        # Ambas listas comparten un solo hueco: mostrarlo con una de las dos ya
        # poblada repetiria la explicacion junto a las filas que la contradicen.
        self.assertIn('root.setting("sourceExclusions", []).length === 0', body)
        self.assertIn('root.setting("targetExclusions", []).length === 0', body)
        self.assertIn("&&", body)
        # El hueco precede a los Repeater, o aparecería debajo de las filas.
        self.assertLess(panel.index("EmptyState {"), panel.index('model: root.setting("sourceExclusions"'))

    def test_empty_state_stays_a_static_text_for_assistive_tools(self) -> None:
        empty = (REPO / "components" / "EmptyState.qml").read_text(encoding="utf-8")
        self.assertIn("Accessible.role: Accessible.StaticText", empty)
        self.assertIn("Accessible.name: root.title", empty)
        self.assertIn("Accessible.description: root.body", empty)
        # Sin foco propio: es un cartel, no una parada del recorrido por teclado.
        self.assertNotIn("focusable: true", empty)

    def test_skip_state_label_keeps_button_padding(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn('"Próxima copia omitida"', panel)
        self.assertNotIn('? "Se omitirá la próxima copia" :', panel)


if __name__ == "__main__":
    unittest.main()
