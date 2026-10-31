# PlateSCT

Scrolling combat text that flies out of **nameplates** in **World of Warcraft 3.3.5a** (Wrath of the Lich King, build 12340).
Your damage, heals and misses appear above the mob you hit, not in the middle of the screen. Crits pop like in the classic Blizzard combat text.

Inspired by NameplateSCT for modern WoW. This is an independent implementation written for the 3.3.5 client.

[Русская версия ниже](#русский)

## Features

- **Numbers on the right plate.**
  - The text appears above the nameplate of the unit you hit.
  - If the mob has no visible plate, it falls back to the screen centre.
- **Classic mode.**
  - Numbers stack in three columns: centre, left and right, so they never overlap.
  - Gap between columns is configurable.
- **Free mode.** Each kind of text gets its own animation: fountain, up, down, rainbow, sideways, classic, shake, or off.
  - Kinds: auto attacks, abilities, crits, misses, heals, incoming.
- **Classic crit pop.** A crit grows to double size and snaps back, like the default UI. The crit size is configurable.
- **Colours.**
  - *Classic*: white melee, yellow spells, green heals.
  - *By spell school*: Fire orange, Shadow violet, and so on.
  - *Custom*: a colour picker for every kind and school. An optional own colour for crits.
- **What to show:**
  - Damage over time, pet and guardian damage, heals, misses, dodges and resists.
  - Spell icons (left, right or both sides).
  - Incoming damage and healing under your character.
- **Off-target text.** Numbers on mobs you are not targeting are smaller and fainter, or hidden.
- **Hide Blizzard numbers.** It turns off the default floating damage. Your previous setting is restored if you turn the option off.
- **Text options.** Font, size, outline, opacity, height above the plate, short numbers (12.3k) or thousands separators.
- English and Russian localisation.
- Works alone. If [WarlockPlates](https://github.com/igotDiamonds/WarlockPlates) is installed, it uses WarlockPlates' plate matching.

## Installation

1. Download the latest code: **Code → Download ZIP**.
2. Extract it and rename the folder from `PlateSCT-main` to **`PlateSCT`**.
3. Put it in `World of Warcraft/Interface/AddOns/`, so the path is `Interface/AddOns/PlateSCT/PlateSCT.toc`.
4. Restart the game. Make sure **PlateSCT** is enabled in the AddOns list on the character screen.

Nameplates must be visible for text to land on them: press **V** (enemy plates).

## Usage

| Command | What it does |
|---|---|
| `/psct` | Open the settings (also under *Interface → AddOns*) |
| `/psct test` | Show sample numbers on your target's nameplate |
| `/psct toggle` | Turn the addon on or off |
| `/psct reset` | Reset all settings |

## License

MIT, see [LICENSE](LICENSE).

---

## Русский

Боевой текст, вылетающий из **индикаторов здоровья** (неймплейтов) в **WoW 3.3.5a**.
Урон, лечение и промахи появляются над мобом, которого вы бьёте, а не в центре экрана. Криты выпрыгивают, как в классическом боевом тексте Blizzard.

Вдохновлён NameplateSCT для современной игры. Код написан с нуля под клиент 3.3.5.

### Возможности

- **Цифры над нужным индикатором.** Если у моба нет видимого индикатора, цифры показываются в центре экрана.
- **Режим «Классика».** Три колонны (центр, слева, справа), цифры не накладываются друг на друга. Расстояние между колоннами настраивается.
- **Свободный режим.** Своя анимация для каждого типа текста: фонтан, вверх, вниз, дуга, в сторону, классика, тряска, выкл.
- **Классическое выпрыгивание крита.** Крит удваивается и сжимается обратно. Размер критов настраивается.
- **Цвета.**
  - «Классика»: урон с руки белый, заклинания жёлтые.
  - «По школам магии».
  - «Свои»: выбор цвета для каждого типа и школы, отдельный цвет критов.
- **Что показывать:**
  - Периодический урон, урон питомца и стражей, лечение, промахи.
  - Иконки заклинаний.
  - Входящий урон и лечение.
- **Не текущая цель.** Текст на других мобах меньше и прозрачнее, или скрыт.
- **Скрыть цифры Blizzard.** Если выключить опцию, прежняя настройка вернётся.
- **Текст.** Шрифт, размер, контур, прозрачность, высота над индикатором, сокращение чисел.
- Работает сам по себе. Если установлен [WarlockPlates](https://github.com/igotDiamonds/WarlockPlates), использует его привязку индикаторов.

### Установка

1. **Code → Download ZIP**, распаковать.
2. Переименовать папку `PlateSCT-main` в **`PlateSCT`**.
3. Положить в `World of Warcraft/Interface/AddOns/`. Путь должен быть `Interface/AddOns/PlateSCT/PlateSCT.toc`.
4. Перезапустить игру и проверить, что аддон включён.

Индикаторы врагов должны быть включены: клавиша **V**.

### Команды

| Команда | Действие |
|---|---|
| `/psct` | Настройки |
| `/psct test` | Пример цифр на индикаторе цели |
| `/psct toggle` | Включить или выключить |
| `/psct reset` | Сброс настроек |
