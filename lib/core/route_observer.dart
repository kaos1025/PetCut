import 'package:flutter/material.dart';

/// 전역 RouteObserver. Home 스크린이 RouteAware로 구독해
/// 다른 route의 pop으로 복귀 시 Recent 섹션을 갱신한다.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
