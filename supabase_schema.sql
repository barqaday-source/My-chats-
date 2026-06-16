-- =============================================
-- محادثاتي (My Chats) - Supabase Schema
-- يطابق تماماً أسماء الجداول في supabase_config.dart
-- =============================================

-- تفعيل UUID
create extension if not exists "uuid-ossp";

-- =============================================
-- جدول المستخدمين (users)
-- SupabaseConfig.tUsers = 'users'
-- =============================================
create table if not exists public.users (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text not null unique,
  email         text,
  avatar_url    text,
  bio           text,
  whatsapp      text,
  birth_date    date,
  zodiac        text,
  role          text not null default 'user' check (role in ('user', 'moderator', 'admin')),
  is_online     boolean not null default false,
  is_blocked    boolean not null default false,
  is_mod        boolean not null default false,
  blocked_at    timestamptz,
  last_seen     timestamptz,
  created_at    timestamptz not null default now()
);

alter table public.users enable row level security;

create policy "users: read all"   on public.users for select using (true);
create policy "users: insert own" on public.users for insert with check (auth.uid() = id);
create policy "users: update own" on public.users for update using (auth.uid() = id);

-- =============================================
-- جدول الغرف (rooms)
-- SupabaseConfig.tRooms = 'rooms'
-- =============================================
create table if not exists public.rooms (
  id               uuid primary key default uuid_generate_v4(),
  name             text not null,
  description      text,
  bio              text,
  background_url   text,
  image_url        text,
  owner_id         uuid not null references public.users(id) on delete cascade,
  owner_name       text not null,
  owner_avatar     text,
  members          uuid[] not null default '{}',
  is_official      boolean not null default false,
  is_locked        boolean not null default false,
  is_approved      boolean not null default false,
  is_follow_enabled boolean not null default true,
  online_count     integer not null default 0,
  member_count     integer not null default 0,
  followers_count  integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.rooms enable row level security;

create policy "rooms: read approved" on public.rooms for select using (is_approved = true or owner_id = auth.uid());
create policy "rooms: insert own"    on public.rooms for insert with check (owner_id = auth.uid());
create policy "rooms: update own"    on public.rooms for update using (owner_id = auth.uid());
create policy "rooms: delete own"    on public.rooms for delete using (owner_id = auth.uid());

-- =============================================
-- جدول أعضاء الغرفة (room_members)
-- SupabaseConfig.tRoomMembers = 'room_members'
-- =============================================
create table if not exists public.room_members (
  id         uuid primary key default uuid_generate_v4(),
  room_id    uuid not null references public.rooms(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  unique(room_id, user_id)
);

alter table public.room_members enable row level security;

create policy "room_members: read all"    on public.room_members for select using (true);
create policy "room_members: insert own"  on public.room_members for insert with check (user_id = auth.uid());
create policy "room_members: delete own"  on public.room_members for delete using (user_id = auth.uid());

-- =============================================
-- جدول المحادثات الخاصة (private_chats)
-- SupabaseConfig.tPrivateChats = 'private_chats'
-- =============================================
create table if not exists public.private_chats (
  id           text primary key,   -- '{sorted_user1_id}_{sorted_user2_id}'
  user1_id     uuid not null references public.users(id) on delete cascade,
  user2_id     uuid not null references public.users(id) on delete cascade,
  last_message text,
  last_message_at timestamptz,
  created_at   timestamptz not null default now()
);

alter table public.private_chats enable row level security;

create policy "private_chats: read participants" on public.private_chats
  for select using (user1_id = auth.uid() or user2_id = auth.uid());
create policy "private_chats: insert participants" on public.private_chats
  for insert with check (user1_id = auth.uid() or user2_id = auth.uid());
create policy "private_chats: update participants" on public.private_chats
  for update using (user1_id = auth.uid() or user2_id = auth.uid());

-- =============================================
-- جدول الرسائل (messages)
-- SupabaseConfig.tMessages = 'messages'
-- =============================================
create table if not exists public.messages (
  id            uuid primary key default uuid_generate_v4(),
  chat_id       text not null,
  sender_id     uuid not null references public.users(id) on delete cascade,
  receiver_id   uuid not null references public.users(id) on delete cascade,
  content       text not null default '',
  type          text not null default 'text' check (type in ('text', 'image', 'audio')),
  media_url     text,
  audio_url     text,
  duration      integer,
  is_read       boolean not null default false,
  sender_name   text,
  sender_avatar text,
  created_at    timestamptz not null default now()
);

create index if not exists messages_chat_id_idx on public.messages(chat_id);
create index if not exists messages_created_at_idx on public.messages(created_at desc);

alter table public.messages enable row level security;

create policy "messages: read own" on public.messages
  for select using (sender_id = auth.uid() or receiver_id = auth.uid());
create policy "messages: insert own" on public.messages
  for insert with check (sender_id = auth.uid());
create policy "messages: update own" on public.messages
  for update using (sender_id = auth.uid() or receiver_id = auth.uid());

-- =============================================
-- جدول الإشعارات (notifications)
-- SupabaseConfig.tNotifications = 'notifications'
-- =============================================
create table if not exists public.notifications (
  id         text primary key,
  user_id    uuid not null references public.users(id) on delete cascade,
  title      text not null,
  body       text not null,
  type       text not null default 'general',
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications(user_id);

alter table public.notifications enable row level security;

create policy "notifications: read own"   on public.notifications for select using (user_id = auth.uid());
create policy "notifications: insert"     on public.notifications for insert with check (true);
create policy "notifications: update own" on public.notifications for update using (user_id = auth.uid());
create policy "notifications: delete own" on public.notifications for delete using (user_id = auth.uid());

-- =============================================
-- جدول البلاغات (reports)
-- SupabaseConfig.tReports = 'reports'
-- =============================================
create table if not exists public.reports (
  id            uuid primary key default uuid_generate_v4(),
  reporter_id   uuid not null references public.users(id) on delete cascade,
  reporter_name text not null,
  reported_id   uuid not null references public.users(id) on delete cascade,
  user_id       uuid references public.users(id),
  reason        text not null,
  status        text not null default 'pending' check (status in ('pending', 'replied')),
  reply         text,
  updated_at    timestamptz,
  created_at    timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "reports: read own" on public.reports
  for select using (reporter_id = auth.uid());
create policy "reports: insert own" on public.reports
  for insert with check (reporter_id = auth.uid());

-- =============================================
-- جدول المحظورين (blocked_users)
-- SupabaseConfig.tBlockedUsers = 'blocked_users'
-- SupabaseConfig.tBlocks        = 'blocks'
-- =============================================
create table if not exists public.blocked_users (
  id          uuid primary key default uuid_generate_v4(),
  blocker_id  uuid not null references public.users(id) on delete cascade,
  blocked_id  uuid not null references public.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique(blocker_id, blocked_id)
);

-- عنوان بديل blocks (alias)
create table if not exists public.blocks (
  id          uuid primary key default uuid_generate_v4(),
  blocker_id  uuid not null references public.users(id) on delete cascade,
  blocked_id  uuid not null references public.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique(blocker_id, blocked_id)
);

alter table public.blocked_users enable row level security;
alter table public.blocks enable row level security;

create policy "blocked_users: manage own" on public.blocked_users
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "blocks: manage own" on public.blocks
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- =============================================
-- جدول معلومات التواصل (contact_info)
-- SupabaseConfig.tContactInfo = 'contact_info'
-- =============================================
create table if not exists public.contact_info (
  id               integer primary key default 1,
  whatsapp_number  text not null default '',
  contact_email    text not null default '',
  support_message  text not null default '',
  updated_at       timestamptz not null default now(),
  constraint single_row check (id = 1)
);

insert into public.contact_info (id, whatsapp_number, contact_email, support_message)
  values (1, '', '', '')
  on conflict (id) do nothing;

alter table public.contact_info enable row level security;

create policy "contact_info: read all"   on public.contact_info for select using (true);
create policy "contact_info: update admin" on public.contact_info
  for update using (
    exists (
      select 1 from public.users
      where id = auth.uid() and (role = 'admin' or role = 'moderator' or is_mod = true)
    )
  );

-- =============================================
-- جدول app_contact (مستخدم في admin_panel_screen)
-- =============================================
create table if not exists public.app_contact (
  id               integer primary key default 1,
  whatsapp_number  text not null default '',
  contact_email    text not null default '',
  support_message  text not null default '',
  updated_at       timestamptz not null default now(),
  constraint app_contact_single_row check (id = 1)
);

insert into public.app_contact (id, whatsapp_number, contact_email, support_message)
  values (1, '', '', '')
  on conflict (id) do nothing;

alter table public.app_contact enable row level security;

create policy "app_contact: read all"    on public.app_contact for select using (true);
create policy "app_contact: update admin" on public.app_contact
  for update using (
    exists (
      select 1 from public.users
      where id = auth.uid() and (role = 'admin' or role = 'moderator' or is_mod = true)
    )
  );

-- =============================================
-- Storage Buckets
-- =============================================
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('room-images', 'room-images', true)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('chat-media', 'chat-media', true)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('audio-messages', 'audio-messages', true)
  on conflict (id) do nothing;

-- Storage policies
create policy "avatars public read"   on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars auth upload"   on storage.objects for insert with check (bucket_id = 'avatars' and auth.role() = 'authenticated');
create policy "avatars auth update"   on storage.objects for update using  (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "room-images public read"  on storage.objects for select using (bucket_id = 'room-images');
create policy "room-images auth upload"  on storage.objects for insert with check (bucket_id = 'room-images' and auth.role() = 'authenticated');

create policy "chat-media auth read"   on storage.objects for select using (bucket_id = 'chat-media' and auth.role() = 'authenticated');
create policy "chat-media auth upload" on storage.objects for insert with check (bucket_id = 'chat-media' and auth.role() = 'authenticated');

create policy "audio-messages auth read"   on storage.objects for select using (bucket_id = 'audio-messages' and auth.role() = 'authenticated');
create policy "audio-messages auth upload" on storage.objects for insert with check (bucket_id = 'audio-messages' and auth.role() = 'authenticated');

-- =============================================
-- دالة تلقائية: إنشاء مستخدم عند التسجيل
-- =============================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
as $$
begin
  insert into public.users (id, username, email, created_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.email,
    now()
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
