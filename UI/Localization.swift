import SwiftUI

// MARK: - Локализация (RU / EN / ES)
// Ключ словаря — русская фраза (она же используется в коде как базовый язык).
// Для RU возвращается сам ключ; для EN/ES — перевод из таблицы.

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru, en, es
    var id: String { rawValue }
    var short: String {
        switch self {
        case .ru: return "RU"
        case .en: return "EN"
        case .es: return "ES"
        }
    }
    var title: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var lang: AppLanguage {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "ru"
        lang = AppLanguage(rawValue: saved) ?? .ru
    }

    /// Перевод по русскому ключу.
    subscript(_ key: String) -> String {
        if lang == .ru { return key }
        guard let row = Self.table[key] else { return key }
        return (lang == .en ? row.0 : row.1)
    }

    func callAsFunction(_ key: String) -> String { self[key] }

    // (EN, ES) по русскому ключу
    static let table: [String: (String, String)] = [
        // Навигация / сайдбар
        "Библиотека": ("Library", "Biblioteca"),
        "Конвертация": ("Conversion", "Conversión"),
        "Дубликаты": ("Duplicates", "Duplicados"),
        "Папки": ("Folders", "Carpetas"),
        "Открыть": ("Open", "Abrir"),
        "Переименовать…": ("Rename…", "Renombrar…"),
        "Удалить…": ("Delete…", "Eliminar…"),
        "Язык": ("Language", "Idioma"),

        // Library header / drop / toolbar
        "Импорт": ("Import", "Importar"),
        "Конвертировать в MP3 320": ("Convert to MP3 320", "Convertir a MP3 320"),
        "Перетащите аудиофайлы или папки": ("Drop audio files or folders", "Arrastra archivos de audio o carpetas"),
        "выбрано": ("selected", "seleccionados"),
        "Формат:": ("Format:", "Formato:"),
        "Конвертировать": ("Convert", "Convertir"),
        "Удалить": ("Delete", "Eliminar"),
        "Отмена": ("Cancel", "Cancelar"),
        "Поиск треков": ("Search tracks", "Buscar pistas"),
        "треков": ("tracks", "pistas"),
        "Готовим библиотеку…": ("Preparing library…", "Preparando biblioteca…"),
        "Треков не найдено": ("No tracks found", "No se encontraron pistas"),

        // Колонки
        "НАЗВАНИЕ": ("TITLE", "TÍTULO"),
        "АРТИСТ": ("ARTIST", "ARTISTA"),
        "ВРЕМЯ": ("TIME", "TIEMPO"),
        "ФОРМАТ": ("FORMAT", "FORMATO"),
        "РАЗМЕР": ("SIZE", "TAMAÑO"),

        // Контекст-меню трека
        "Играть": ("Play", "Reproducir"),
        "Показать в Finder": ("Reveal in Finder", "Mostrar en Finder"),
        "Выбрать": ("Select", "Seleccionar"),
        "Выбрать всё": ("Select All", "Seleccionar todo"),
        "Снять выделение": ("Deselect All", "Deseleccionar"),
        "Убрать из библиотеки": ("Remove from Library", "Quitar de la biblioteca"),

        // Алерты
        "Ошибка библиотеки": ("Library Error", "Error de biblioteca"),
        "Убрать треки": ("Remove Tracks", "Quitar pistas"),
        "Убрать": ("Remove", "Quitar"),

        // Инспектор
        "Инфо": ("Info", "Info"),
        "Метаданные": ("Metadata", "Metadatos"),
        "Трек не выбран": ("No track selected", "Ninguna pista seleccionada"),
        "Анализ аудио 2.0": ("Audio Analysis 2.0", "Análisis de audio 2.0"),
        "Тональность": ("Musical Key", "Tonalidad"),
        "Темп": ("Tempo", "Tempo"),
        "Выберите трек,\nчтобы увидеть метаданные": ("Select a track\nto see its metadata", "Selecciona una pista\npara ver los metadatos"),
        "Название": ("Title", "Título"),
        "Артист": ("Artist", "Artista"),
        "Альбом": ("Album", "Álbum"),
        "Артист альбома": ("Album Artist", "Artista del álbum"),
        "Жанр": ("Genre", "Género"),
        "Год": ("Year", "Año"),
        "Трек": ("Track", "Pista"),
        "Диск": ("Disc", "Disco"),
        "Композитор": ("Composer", "Compositor"),
        "Группа": ("Grouping", "Agrupación"),
        "Лейбл": ("Label", "Sello"),
        "Комментарий": ("Comment", "Comentario"),
        "Копирайт": ("Copyright", "Copyright"),
        "Сохранить метаданные": ("Save Metadata", "Guardar metadatos"),
        "Сохранение…": ("Saving…", "Guardando…"),
        "Заменить": ("Replace", "Reemplazar"),
        "Обложка удалена": ("Artwork removed", "Portada eliminada"),
        "Перетащите или нажмите «Заменить»": ("Drop image or click Replace", "Suelta una imagen o pulsa Reemplazar"),
        "В файл записываются только изменённые поля.": ("Only edited fields are written to the file.", "Solo se escriben los campos editados."),
        "Неизвестный альбом": ("Unknown Album", "Álbum desconocido"),
        "Громкость": ("Loudness", "Volumen"),
        "Формат": ("Format", "Formato"),
        "Частота": ("Sample Rate", "Frecuencia"),
        "Битность": ("Bit Depth", "Profundidad"),
        "Каналы": ("Channels", "Canales"),
        "Битрейт": ("Bitrate", "Tasa de bits"),
        "Стерео": ("Stereo", "Estéreo"),
        "Моно": ("Mono", "Mono"),
        "Папка назначения": ("Destination folder", "Carpeta de destino"),
        "Изменить метаданные": ("Edit Metadata", "Editar metadatos"),

        // Плеер
        "Очередь конвертации": ("Conversion Queue", "Cola de conversión"),
        "файлов": ("files", "archivos"),
        "Очередь пуста": ("Queue Empty", "Cola vacía"),
        "Задания конвертации lossless → MP3 и другие.": ("Lossless-to-MP3 and other conversion jobs.", "Trabajos de conversión sin pérdida a MP3 y otros."),
        "Очистить завершённые": ("Clear Completed", "Limpiar completados"),
        "Выберите треки в библиотеке и нажмите «Конвертировать».": ("Select tracks in the library and press Convert.", "Selecciona pistas en la biblioteca y pulsa Convertir."),
        "В формат:": ("To:", "A:"),
        "Удалить задание": ("Remove Job", "Eliminar trabajo"),
        "Отменить задание": ("Cancel Job", "Cancelar trabajo"),
        "Отменить всё": ("Cancel All", "Cancelar todo"),
        "Готово": ("Done", "Listo"),
        "Ошибка": ("Failed", "Error"),
        "В очереди": ("Queued", "En cola"),
        "Подготовка": ("Preparing", "Preparando"),
        "Конвертирование": ("Converting", "Convirtiendo"),
        "Отменено": ("Cancelled", "Cancelado"),

        // Дубликаты
        "Найдены возможные дубликаты. Отметьте треки для перемещения в Корзину.": ("Potential duplicate tracks found. Select tracks to move to Trash.", "Se encontraron posibles duplicados. Selecciona pistas para mover a la Papelera."),
        "Дубликатов не найдено": ("No Duplicates Found", "No se encontraron duplicados"),
        "Библиотека выглядит чистой.": ("Your library looks clean.", "Tu biblioteca está limpia."),

        // Splash
        "БИБЛИОТЕКА · АНАЛИЗ · КОНВЕРТАЦИЯ": ("LIBRARY · ANALYSIS · CONVERSION", "BIBLIOTECA · ANÁLISIS · CONVERSIÓN"),

        // Диалоги папки
        "Удалить папку": ("Delete Folder", "Eliminar carpeta"),
        "Убрать только из приложения": ("Remove from App Only", "Quitar solo de la app"),
        "Переместить в Корзину Mac": ("Move to Mac Trash", "Mover a la Papelera"),
        "Переименовать папку": ("Rename Folder", "Renombrar carpeta"),
        "Новое имя": ("New name", "Nuevo nombre"),
        "В приложении": ("In App Only", "Solo en la app"),
        "Переименовать на Mac": ("Rename on Mac", "Renombrar en Mac"),

        // Статусы библиотеки (нижний статус-бар). %d — число, %@ — текст ошибки.
        "Библиотека занята. Дождитесь завершения текущей операции.": ("Library is busy. Please wait for the current operation to finish.", "La biblioteca está ocupada. Espera a que termine la operación actual."),
        "Не удалось получить доступ к выбранным объектам: %@": ("Could not access the selected items: %@", "No se pudo acceder a los elementos seleccionados: %@"),
        "Не удалось прочитать выбранную обложку: %@": ("Could not read the selected artwork: %@", "No se pudo leer la portada seleccionada: %@"),
        "Не удалось получить доступ к выбранной обложке: %@": ("Could not access the selected artwork: %@", "No se pudo acceder a la portada seleccionada: %@"),
        "Выберите хотя бы один трек перед изменением метаданных.": ("Select at least one track before applying metadata changes.", "Selecciona al menos una pista antes de aplicar cambios de metadatos."),
        "Выберите хотя бы одно поле метаданных.": ("Choose at least one metadata field to apply.", "Elige al menos un campo de metadatos para aplicar."),
        "Нет доступных файлов или папок.": ("No accessible files or folders were provided.", "No se proporcionaron archivos ni carpetas accesibles."),
        "Сканирование выбранного (%d)…": ("Scanning %d selected item(s)…", "Escaneando %d elemento(s) seleccionado(s)…"),
        "Новых поддерживаемых аудиофайлов не найдено. Пропущено: %d.": ("No new supported audio files found. Skipped %d item(s).", "No se encontraron nuevos audios compatibles. Omitidos: %d."),
        "Чтение технических метаданных (%d)…": ("Reading technical metadata for %d track(s)…", "Leyendo metadatos técnicos de %d pista(s)…"),
        "Чтение тегов и обложек (%d)…": ("Reading tags and artwork for %d track(s)…", "Leyendo etiquetas y portadas de %d pista(s)…"),
        "Добавлено треков: %d.": ("Added %d track(s).", "Pistas añadidas: %d."),
        " Технические метаданные недоступны для %d.": (" Technical metadata was unavailable for %d track(s).", " Metadatos técnicos no disponibles para %d."),
        " Технические метаданные прочитаны для всех треков.": (" Read technical metadata for all tracks.", " Metadatos técnicos leídos para todas las pistas."),
        " Теги недоступны для %d.": (" Metadata was unavailable for %d track(s).", " Etiquetas no disponibles para %d."),
        " Теги прочитаны для %d.": (" Read tags for %d track(s).", " Etiquetas leídas para %d."),
        " Пропущено: %d.": (" Skipped %d item(s).", " Omitidos: %d."),
        " Библиотека сохранена.": (" Library saved locally.", " Biblioteca guardada localmente."),
        " Не удалось сохранить библиотеку.": (" The library could not be saved locally.", " No se pudo guardar la biblioteca localmente."),
        "Восстановление сохранённой библиотеки…": ("Restoring saved library…", "Restaurando la biblioteca guardada…"),
        "Восстановлено треков: %d. Недоступно: %d.": ("Restored %d track(s). %d saved track(s) were unavailable.", "Restauradas %d pista(s). %d no disponibles."),
        "Восстановлено треков из сохранённой библиотеки: %d.": ("Restored %d track(s) from the saved library.", "Restauradas %d pista(s) de la biblioteca guardada."),
        "Не удалось восстановить сохранённую библиотеку: %@": ("Saved library could not be restored: %@", "No se pudo restaurar la biblioteca guardada: %@"),
        "Применение изменений метаданных (%d)…": ("Applying metadata changes to %d track(s)…", "Aplicando cambios de metadatos a %d pista(s)…"),
        "Изменения метаданных не удалось сохранить. Изменения не применены.": ("Metadata changes could not be saved locally. No library changes were kept.", "No se pudieron guardar los cambios de metadatos. No se conservaron cambios."),
        "Изменения метаданных применены (%d), библиотека сохранена.": ("Applied metadata changes to %d track(s) and saved the library.", "Cambios de metadatos aplicados (%d) y biblioteca guardada."),
        "Не удалось переместить папку в Корзину: %@": ("Could not move folder to trash: %@", "No se pudo mover la carpeta a la Papelera: %@"),
        "Не удалось переименовать папку на Mac: %@": ("Failed to rename folder on Mac: %@", "No se pudo renombrar la carpeta en Mac: %@"),
    ]
}
