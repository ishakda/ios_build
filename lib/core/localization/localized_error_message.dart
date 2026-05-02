import 'package:flutter/material.dart';
import 'package:untitled1/core/localization/app_localizations.dart';

String localizeErrorMessage(
  BuildContext context,
  Object? error, {
  String fallbackKey = 'generic_error_retry',
}) {
  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return context.translate(fallbackKey);
  }

  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Error:\s*', caseSensitive: false), '')
      .trim();
  final normalized = cleaned.toLowerCase();

  if (normalized.contains('email not confirmed')) {
    return context.translate('verify_email_before_sign_in');
  }
  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return context.translate('invalid_login_credentials');
  }
  if (normalized.contains('google sign-in error')) {
    return context.translate('google_sign_in_failed');
  }
  if (normalized.contains('unable to update this order right now')) {
    return context.translate('update_order_failed');
  }
  if (normalized.contains('we could not load store orders right now')) {
    return context.translate('store_orders_load_error');
  }
  if (normalized.contains(
    'we could not load this store\'s products right now',
  )) {
    return context.translate('store_products_load_error');
  }
  if (normalized.contains(
    'we could not load your seller analytics right now',
  )) {
    return context.translate('seller_analytics_load_error');
  }
  if (normalized.contains('unable to update follow status')) {
    return context.translate('update_follow_failed');
  }
  if (normalized.contains('unable to update store details right now')) {
    return context.translate('update_store_details_failed');
  }
  if (normalized.contains('unable to upload this image right now')) {
    return context.translate('upload_store_image_failed_generic');
  }
  if (normalized.contains('invalid checkout response from server') ||
      normalized.contains('invalid shipment response from server')) {
    return context.translate('invalid_server_response');
  }
  if (normalized.contains('missing checkout url')) {
    return context.translate('missing_checkout_url');
  }
  if (normalized.contains('invalid checkout url')) {
    return context.translate('invalid_checkout_url');
  }
  if (normalized.contains('could not open payment page')) {
    return context.translate('open_payment_page_failed');
  }
  if (normalized.contains('could not submit your review') ||
      normalized.contains('review submit')) {
    return context.translate('review_submit_failed');
  }
  if (normalized.contains('profile update') ||
      normalized.contains('could not update your profile')) {
    return context.translate('profile_update_failed_generic');
  }

  if (_isNonEnglishUserMessage(cleaned)) {
    return cleaned;
  }

  if (_looksTechnicalMessage(normalized)) {
    return context.translate(fallbackKey);
  }

  return cleaned;
}

bool _looksTechnicalMessage(String message) {
  return message.contains('exception') ||
      message.contains('postgrest') ||
      message.contains('socket') ||
      message.contains('timeout') ||
      message.contains('failed') ||
      message.contains('invalid') ||
      message.contains('permission') ||
      message.contains('unauthorized') ||
      message.contains('unexpected') ||
      message.contains('null') ||
      message.contains('server');
}

bool _isNonEnglishUserMessage(String value) {
  final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  final hasFrenchAccents = RegExp(
    r'[àâçéèêëîïôùûüÿœæÀÂÇÉÈÊËÎÏÔÙÛÜŸŒÆ]',
  ).hasMatch(value);
  return hasArabic || hasFrenchAccents;
}
