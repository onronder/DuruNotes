/**
 * Multi-language notification messages
 * Supports: English (en), Turkish (tr)
 * Add more languages as needed
 */

export type NotificationLanguage = 'en' | 'tr';

export interface NotificationMessage {
  title: string;
  body: string;
}

/**
 * Get user's preferred language from database or default to English
 */
export async function getUserLanguage(supabase: any, userId: string): Promise<NotificationLanguage> {
  try {
    const { data } = await supabase
      .from('user_preferences')
      .select('language')
      .eq('user_id', userId)
      .single();

    if (data?.language && ['en', 'tr'].includes(data.language)) {
      return data.language as NotificationLanguage;
    }
  } catch (e) {
    // If error or no preference, default to English
  }

  return 'en'; // Default language
}

/**
 * Email received notification messages
 */
export function getEmailReceivedMessage(
  senderName: string,
  subject: string,
  language: NotificationLanguage
): NotificationMessage {
  const messages = {
    en: {
      title: '📧 New Email in Inbox',
      body: `From ${senderName}: ${subject}\n\nEmail note is ready to convert to a note.`,
    },
    tr: {
      title: '📧 Gelen Kutunuzda Yeni E-posta',
      body: `Gönderen ${senderName}: ${subject}\n\nE-posta notu dönüştürmeye hazır.`,
    },
  };

  return messages[language] || messages.en;
}

/**
 * Web clip saved notification messages
 */
export function getWebClipSavedMessage(
  preview: string,
  language: NotificationLanguage
): NotificationMessage {
  const messages = {
    en: {
      title: '✂️ Content Clipped Successfully',
      body: `${preview}\n\nSaved to your inbox and ready to use.`,
    },
    tr: {
      title: '✂️ İçerik Başarıyla Kaydedildi',
      body: `${preview}\n\nGelen kutunuza kaydedildi ve kullanıma hazır.`,
    },
  };

  return messages[language] || messages.en;
}

/**
 * Task reminder notification messages
 */
export function getTaskReminderMessage(
  taskTitle: string,
  language: NotificationLanguage
): NotificationMessage {
  const messages = {
    en: {
      title: '⏰ Task Reminder',
      body: `${taskTitle}\n\nDue now!`,
    },
    tr: {
      title: '⏰ Görev Hatırlatıcısı',
      body: `${taskTitle}\n\nŞimdi yapılmalı!`,
    },
  };

  return messages[language] || messages.en;
}

/**
 * Task assigned notification messages
 */
export function getTaskAssignedMessage(
  taskTitle: string,
  dueDate: string,
  language: NotificationLanguage
): NotificationMessage {
  const messages = {
    en: {
      title: '📋 New Task with Reminder',
      body: `${taskTitle}\nDue: ${dueDate}\n\nReminder is set and will notify you.`,
    },
    tr: {
      title: '📋 Hatırlatıcılı Yeni Görev',
      body: `${taskTitle}\nTarih: ${dueDate}\n\nHatırlatıcı ayarlandı ve sizi bilgilendirecek.`,
    },
  };

  return messages[language] || messages.en;
}

/**
 * Note shared notification messages
 */
export function getNoteSharedMessage(
  noteTitle: string,
  language: NotificationLanguage
): NotificationMessage {
  const messages = {
    en: {
      title: '📝 Note Shared with You',
      body: `${noteTitle}\n\nCheck it out in your shared notes.`,
    },
    tr: {
      title: '📝 Sizinle Not Paylaşıldı',
      body: `${noteTitle}\n\nPaylaşılan notlarınızda görüntüleyin.`,
    },
  };

  return messages[language] || messages.en;
}
