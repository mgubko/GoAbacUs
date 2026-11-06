# GoAbacUs

Учебные счёты для младших школьников: планшет (Android, затем iOS), без интернета.
Ребёнок двигает костяшки пальцами и наклоном устройства, а приложение показывает число.

Learning abacus (Russian школьные счёты) for kids 6+. Offline, tablet-first, Flutter.
UI languages: Russian, English, German, French, Spanish.

## Что уже есть

- 10 спиц по 10 костяных костяшек, две чёрные в середине; единицы на нижней спице.
- Физика (`lib/physics/abacus_physics.dart`, единицы СИ): инерция, трение покоя и скольжения,
  упругие удары кость–кость и кость–рамка, палец как пружина с ограниченной силой
  (чем больше костяшек толкаешь, тем они тяжелее и медленнее), гравитация от наклона.
- Звуки ударов вырезаны из записи настоящих деревянных счётов: `tool/cut_sounds.py`.
  Громкость зависит от скорости удара, звук только при новом ударе.
- Вибрация при ударе о рамку, сила по импульсу движущейся группы.
- Текстуры дерева и кости сгенерированы Gemini: `assets/images/`.
- Число на счётах и цифра каждого ряда считываются по положению костяшек.

## Сборка

```bash
flutter pub get
flutter test
flutter run                 # на подключённом планшете
```

## GitHub Actions

`.github/workflows/android.yml`:

- каждый push и PR: анализ, тесты и **debug APK** (артефакт `goabacus-debug-apk`);
- тег `v1.2.3` или ручной запуск: **подписанные AAB (для Google Play) и APK**,
  артефакт `goabacus-release`; для тега ещё и GitHub Release с файлами.

### iPad / iPhone

`.github/workflows/ios.yml` собирает **неподписанный .ipa** (артефакт
`goabacus-ios-unsigned`) по тегу `v*` или вручную: *Actions → iOS build → Run workflow*.
macOS-сборка в приватном репозитории тратит минуты Actions в 10 раз быстрее, поэтому не на каждый push.

Установить неподписанный .ipa на iPad можно через Sideloadly или AltStore с вашим Apple ID
(бесплатный аккаунт: приложение работает 7 дней, потом переустановить).
Для TestFlight и App Store нужен Apple Developer Program, тогда добавим подпись в CI.

### Подпись релиза (Release signing)

1. Один раз создайте ключ загрузки: `tool/make_upload_key.sh` (нужен JDK).
   Сохраните `.jks` и пароль в надёжном месте, в репозиторий их не кладите.
2. Добавьте секреты в *Settings → Secrets and variables → Actions*:
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
3. Выпуск версии: `git tag v0.1.0 && git push origin v0.1.0`.

В Google Play включите Play App Signing: Google хранит ключ подписи приложения,
а этот ключ используется только для загрузки.
