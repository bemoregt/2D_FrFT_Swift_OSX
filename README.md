# FrFTViewer

macOS용 SwiftUI 앱입니다.

이미지를 창에 드래그 앤 드롭하면:

- 왼쪽에 원본 이미지를 표시합니다.
- 오른쪽에 2차원 분수 푸리에 변환(FrFT) 결과를 표시합니다.
- `alpha` 값은 슬라이더로 실시간 조절됩니다.

## 기능

- 이미지 파일 드래그 앤 드롭 지원
- 원본/변환 결과를 나란히 표시
- `alpha` 0.00 ~ 2.00 실시간 제어
- 드래그가 들어오면 윈도우 테두리 강조
- 변환 계산은 백그라운드 작업으로 처리

## 요구 사항

- macOS
- Xcode 26 이상 권장
- Swift 6

## 실행 방법

1. `FrFTViewer.xcodeproj`를 Xcode로 엽니다.
2. `FrFTViewer` 스킴을 선택합니다.
3. Run을 누릅니다.
4. 이미지 파일을 앱 창에 드롭합니다.
5. 슬라이더로 `alpha` 값을 조절합니다.

## 구현 메모

- UI는 SwiftUI로 구성했습니다.
- FrFT 결과는 복소수 크기(magnitude)를 그레이스케일 이미지로 시각화합니다.
- 계산량을 줄이기 위해 입력 이미지는 렌더링용으로 적절히 축소합니다.
- 현재 구현은 실시간 반응을 우선한 근사 discrete 2D FrFT입니다.

## 파일 구조

- `FrFTViewer/FrFTViewerApp.swift`
- `FrFTViewer/ContentView.swift`
- `FrFTViewer/FrFTViewModel.swift`
- `FrFTViewer/FrFTProcessor.swift`

## 참고

현재 구현의 FrFT는 교육용/시각화용 성격이 강합니다. 더 정확한 수학적 정의나 더 빠른 처리 방식이 필요하면 추가 개선할 수 있습니다.

