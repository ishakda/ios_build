import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LanguageState {
  final Locale locale;
  const LanguageState(this.locale);
}

abstract class LanguageEvent {}

class ChangeLanguage extends LanguageEvent {
  final String languageCode;
  ChangeLanguage(this.languageCode);
}

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  LanguageBloc() : super(const LanguageState(Locale('en'))) {
    on<ChangeLanguage>((event, emit) async {
      final locale = Locale(event.languageCode);
      emit(LanguageState(locale));
      final box = Hive.box('settings');
      await box.put('language', event.languageCode);
    });

    _loadSavedLanguage();
  }

  void _loadSavedLanguage() {
    final box = Hive.box('settings');
    final String languageCode = box.get('language', defaultValue: 'en');
    add(ChangeLanguage(languageCode));
  }
}
