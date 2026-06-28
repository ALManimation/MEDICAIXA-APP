# Adversarial Challenge Report — Settings & C++ Box Integration

## Challenge Summary

**Overall risk assessment**: LOW

The Settings UI layout and C++ integration are highly robust. The app correctly implements visual guides and guards when disconnected, handles dialog validations properly, enforces uppercase conversion for confirmation prompts, prevents layout overflow for empty states, and validates data boundary inputs on the SQLite/Drift layers.

---

## Challenges

### [Low] Challenge 1: Dialog height overflow on small viewports
- **Assumption challenged**: Assumed the reset dialog layout would always comfortably fit within mobile viewports.
- **Attack scenario**: On smaller viewports (e.g. 800x600 test layout or small phones), the large number of partition checkboxes (9 partitions + Factory Reset) causes the dialog to exceed height bounds.
- **Blast radius**: The user needs to scroll to reach confirmation fields. In widget testing, attempts to interact with checkboxes/inputs without ensuring visibility would fail hit-testing.
- **Mitigation**: The developers already wrapped the dialog body in a `SingleChildScrollView`, which prevents hard crashes or layout exceptions. However, adding explicit scroll indicators or dividing the partitions into columns could improve the UX on smaller screens.

### [Low] Challenge 2: Long patient names in Dashboard Greeting
- **Assumption challenged**: Assumed patient names would be short/reasonable lengths.
- **Attack scenario**: Saving a patient name of extreme length (e.g., 100+ characters) is successfully permitted by Drift DB. In the dashboard screen, this name is displayed in a greeting row.
- **Blast radius**: While the `Text` widget is inside an `Expanded` card column and wraps lines cleanly without throwing layout overflow exceptions, it can visual-distort the dashboard top bar space.
- **Mitigation**: Add a character limit (e.g., `maxLength: 30`) to the name input text field in `settings_screen.dart`.

---

## Stress Test Results

- **Transitions between Connected and Standalone States** → Disconnected shows warning card, ignores pointer, and has `0.55` opacity. Transitioning to connected removes warning card and enables inputs. → **PASS**
- **Selective Partition Resets (Factory Reset Check)** → Tapping 'RESET DE FÁBRICA (Tudo)' disables individual checkboxes (sets `onChanged` to `null`). → **PASS**
- **Uppercase 'APAGAR' match check** → Entering invalid text (e.g. 'APAGA') disables submit button. Entering 'apagar' formats automatically to 'APAGAR' and enables submit button. → **PASS**
- **TextInputFormatter (UpperCaseTextFormatter)** → Verifies lowercase characters auto-convert to uppercase in reset confirmation. → **PASS**
- **Extreme Brightness and Speaker Volume Boundaries** → Storing `0` and `100` values directly in SQLite database. → **PASS**
- **Empty SSID lists on Wi-Fi config** → Displays empty states "Nenhuma rede Wi-Fi salva no dispositivo" and "Nenhuma rede Wi-Fi encontrada" correctly. → **PASS**
- **Long Patient Name Persistence** → Storing 100-character name successfully updates Drift DB. → **PASS**

---

## Unchallenged Areas

- **Native File Picker and Share Sheet Interactions** — These interact with native platform services (`file_picker`, `share_plus`) which cannot be fully unit/widget tested in the flutter_test framework environment without mocking out native platform channels.
