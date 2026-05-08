import '../../core/utils/string_utils.dart';

class CategoryModel {
  final String id;
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromRow(List<dynamic> row) {
    return CategoryModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      name: row.length > 1 ? row[1].toString() : '',
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      StringExtensions.titleCase(name),
    ];
  }
}

/*
SQL to create profiles table in Supabase:

create table public.profiles (
  id uuid references auth.users not null primary key,
  username text,
  avatar_url text,
  updated_at timestamp with time zone
);

alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on profiles
  for update using (auth.uid() = id);
*/
