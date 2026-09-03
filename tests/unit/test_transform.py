from __future__ import annotations

import codecs
import unittest

from omaplain_lib.config import DEFAULTS
from omaplain_lib.transform import TransformBypass, clean_tracking_url, decode_text, transform


class TransformTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = dict(DEFAULTS)

    def test_line_endings_are_normalized_without_dropping_final_newline(self) -> None:
        result = transform(b"one\r\ntwo\rthree\r\n", "text/plain", self.config)
        self.assertEqual(result.output, b"one\ntwo\nthree\n")
        self.assertIn("line_endings", result.transformations)

    def test_conservative_invisibles_are_removed(self) -> None:
        source = "a\u00adb\u200bc\u2060d\ufeffe".encode()
        self.assertEqual(transform(source, "text/plain", self.config).output, b"abcde")

    def test_initial_bom_is_decoded_and_internal_feff_is_removed(self) -> None:
        source = "\ufeffuno\ufeffdos".encode()
        result = transform(source, "text/plain", self.config)
        self.assertEqual(result.output.decode(), "unodos")

    def test_zwj_zwnj_variations_and_bidi_are_preserved(self) -> None:
        source = "👨‍👩‍👧‍👦 می‌روم العربية\u202e ✈️"
        result = transform(source.encode(), "text/plain", self.config)
        self.assertEqual(result.output.decode(), source)

    def test_tracking_query_is_removed_without_reencoding_remaining_url(self) -> None:
        source = "  https://Example.com/a%2Fb?q=a+b&utm_source=news&x=%2F#frag  "
        expected = "  https://Example.com/a%2Fb?q=a+b&x=%2F#frag  "
        self.assertEqual(clean_tracking_url(source), expected)

    def test_all_tracking_parameters_remove_question_mark(self) -> None:
        self.assertEqual(clean_tracking_url("https://example.com/a?utm_source=x#top"), "https://example.com/a#top")

    def test_repeated_functional_parameters_keep_order(self) -> None:
        source = "https://example.com/?a=1&utm_medium=x&a=2&b="
        self.assertEqual(clean_tracking_url(source), "https://example.com/?a=1&a=2&b=")

    def test_signed_urls_are_byte_for_byte_unchanged(self) -> None:
        urls = [
            "https://s3.example/x?X-Amz-Signature=ABC&utm_source=x",
            "https://example.com/x?token=abc&utm_source=x",
            "https://example.com/x?Expires=10&Signature=abc&utm_source=x",
        ]
        for source in urls:
            with self.subTest(source=source):
                self.assertEqual(clean_tracking_url(source), source)

    def test_text_containing_a_url_is_not_modified(self) -> None:
        source = "See https://example.com/?utm_source=x"
        self.assertEqual(clean_tracking_url(source), source)

    def test_invalid_percent_encoding_fails_closed(self) -> None:
        source = "https://example.com/?utm%ZZ_source=x&a=1"
        self.assertEqual(clean_tracking_url(source), source)

    def test_optional_normalizers_are_independent(self) -> None:
        self.config.update({"normalizeQuotes": True, "normalizeLists": True, "trimTrailingWhitespace": True})
        result = transform("“Hi”  \n • item  ".encode(), "text/plain", self.config)
        self.assertEqual(result.output.decode(), '"Hi"\n - item')

    def test_nfc_is_off_by_default(self) -> None:
        source = "e\u0301"
        self.assertEqual(transform(source.encode(), "text/plain", self.config).output.decode(), source)
        self.config["normalizeUnicodeNfc"] = True
        self.assertEqual(transform(source.encode(), "text/plain", self.config).output.decode(), "é")

    def test_utf8_bom_and_utf16_are_decoded_strictly(self) -> None:
        self.assertEqual(decode_text(codecs.BOM_UTF8 + b"hello", "text/plain"), "hello")
        encoded = "hola".encode("utf-16")
        self.assertEqual(decode_text(encoded, "text/plain;charset=utf-16"), "hola")

    def test_invalid_utf8_and_nul_are_bypassed(self) -> None:
        with self.assertRaisesRegex(TransformBypass, "invalid_text"):
            transform(b"\xff", "text/plain;charset=utf-8", self.config)
        with self.assertRaisesRegex(TransformBypass, "nul"):
            transform(b"a\x00b", "text/plain", self.config)

    def test_size_limit_is_enforced(self) -> None:
        self.config["maxBytes"] = 4
        with self.assertRaisesRegex(TransformBypass, "too_large"):
            transform(b"hello", "text/plain", self.config)


if __name__ == "__main__":
    unittest.main()


class CadaReglaObedeceSuInterruptorTests(unittest.TestCase):
    """Apagar una regla la apaga. Encenderla la enciende.

    Las ocho reglas del panel estaban probadas por su efecto —con la
    configuración de serie, el motor quita el seguimiento, los invisibles y
    los finales de línea de Windows—, pero **cuatro de ellas no tenían un
    solo test que las apagara**: las cuatro que vienen puestas.

    Y ése es justo el caso que le importa a quien toca Ajustes. Si una
    regresión hiciera que `removeTracking` ignorara su interruptor, la
    suite entera seguiría en verde: todos los tests la usan encendida.

    La tabla va con un ejemplo por regla que sólo esa regla cambia, y
    comprueba las dos direcciones sobre el mismo texto.
    """

    MIME = "text/plain;charset=utf-8"

    # regla -> (texto de entrada, qué deja el motor con la regla puesta)
    CASOS = {
        "removeTracking": (
            "https://example.com/a?utm_source=x&id=7",
            "https://example.com/a?id=7",
        ),
        "removeInvisible": ("ho​la", "hola"),
        "normalizeLineEndings": ("uno\r\ndos", "uno\ndos"),
        "normalizeQuotes": ("“hola”", '"hola"'),
        "normalizeLists": ("• uno", "- uno"),
        "normalizeUnicodeNfc": ("café", "café"),
        "trimTrailingWhitespace": ("uno   \ndos", "uno\ndos"),
    }

    def _config(self, encendida: str | None) -> dict:
        """Todas las reglas de texto apagadas menos, si acaso, una."""
        config = dict(DEFAULTS)
        for clave, valor in DEFAULTS.items():
            if isinstance(valor, bool) and clave != "automatic":
                config[clave] = False
        if encendida:
            config[encendida] = True
        return config

    def test_encendida_cada_regla_hace_lo_que_dice_su_rotulo(self) -> None:
        for regla, (entrada, esperado) in self.CASOS.items():
            with self.subTest(regla=regla):
                salida = transform(entrada.encode("utf-8"), self.MIME,
                                   self._config(regla)).output.decode("utf-8")
                self.assertEqual(salida, esperado)

    def test_apagada_cada_regla_deja_el_texto_intacto(self) -> None:
        for regla, (entrada, _) in self.CASOS.items():
            with self.subTest(regla=regla):
                salida = transform(entrada.encode("utf-8"), self.MIME,
                                   self._config(None)).output.decode("utf-8")
                self.assertEqual(salida, entrada, f"{regla} sigue actuando apagada")

    def test_ninguna_regla_pisa_el_ejemplo_de_otra(self) -> None:
        """Y la tabla es honesta: cada ejemplo lo cambia **sólo** su regla.

        Sin esto, un ejemplo que dos reglas tocan haría pasar la prueba de
        la regla equivocada.
        """
        for regla, (entrada, _) in self.CASOS.items():
            for otra in self.CASOS:
                if otra == regla:
                    continue
                with self.subTest(ejemplo=regla, regla=otra):
                    salida = transform(entrada.encode("utf-8"), self.MIME,
                                       self._config(otra)).output.decode("utf-8")
                    self.assertEqual(salida, entrada,
                                     f"el ejemplo de {regla} lo cambia también {otra}")
