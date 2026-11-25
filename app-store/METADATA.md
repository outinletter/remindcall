# App Store 제출 정보 — RemindCall 1.0

| 항목 | 값 |
|---|---|
| 번들 ID | com.addvalue.remindcall (확장: com.addvalue.remindcall.directory) |
| 앱 이름 | RemindCall |
| 부제목(30자) | 통화 전에 보는 연락처 카드 |
| 기본 언어 | 한국어 |
| 카테고리 | 주: 생산성 / 부: 유틸리티 |
| 연령 등급 | 4+ (모든 질문 "없음") |
| 가격 | 무료 |
| 저작권 | 2026 BS Jeon |
| 개인정보 처리방침 | https://outinletter.github.io/privacy-policy/remindcall.html |
| 지원 URL | https://github.com/outinletter/remindcall |
| 앱 프라이버시 | 데이터 수집 없음 (연락처는 기기 안에서만 사용, 앱 데이터는 사용자의 개인 iCloud) |
| 수출 규정 | 암호화 사용 안 함(표준 면제 포함 아님) → ITSAppUsesNonExemptEncryption = NO |
| 광고 식별자(IDFA) | 사용 안 함 |

## 프로모션 텍스트 (170자)

전화를 걸기 전에 상대의 번호, 생일, 메모, 마지막 연락을 한 장의 카드로 확인하세요. 번호 뒷자리만 눌러도 누구인지 바로 알려 드려요.

## 설명

스마트폰을 쓰다 보면 상대의 이름만 보이고 번호도, 지난 대화도 기억나지 않습니다. RemindCall은 연락처의 번호·생일과 내가 남긴 메모를 한 장의 카드로 보여 줍니다.

■ 연락처 카드
- 이름, 번호, 회사, 생일 D-day, 메모, 태그, 마지막 연락을 한 화면에
- 카드에서 바로 전화 걸기
- 오른쪽으로 밀거나 아래로 끌어 내려 닫기

■ 키패드 조회
- 번호 뒷자리만 눌러도 일치하는 연락처가 나타납니다
- 연락처에 없는 번호도 바로 전화할 수 있어요

■ 즐겨찾기와 정렬
- 자주 연락하는 사람을 카드로 모아 보기
- 이름순, 최근 연락순, 연락 오래된 순, 생일 임박순

■ 내 방식대로 표시
- 목록과 즐겨찾기 카드에 보여 줄 정보와 순서를 직접 선택
- 미리보기를 보며 바로 확인

■ 필요한 기능만 켜기 (설정에서 선택)
- 통화 후 메모 알림: 알림을 길게 눌러 앱을 열지 않고 메모 남기기
- 생일 알림: 당일 또는 하루 전
- 모르는 번호 이름표: 연락처에 없는 번호에서 전화가 올 때 이름표 표시

■ 개인정보
- 광고·분석·추적이 없고 계정도 필요 없습니다
- 연락처는 기기 밖으로 나가지 않으며, 메모와 설정은 나의 iCloud로만 동기화됩니다
- 통화 내용을 녹음하거나 문자·시스템 통화 기록을 읽지 않습니다

※ iOS 정책상 시스템 전화 앱의 통화 기록과 수신 화면에는 개입할 수 없습니다. 앱의 통화 기록은 RemindCall에서 전화 버튼으로 건 통화만 표시합니다.

## 키워드 (100자 이내)

연락처,전화,메모,생일,키패드,즐겨찾기,통화,전화번호,태그,카드,알림,번호조회,기억

## 심사 노트 (Notes for Review)

No account or sign-in is required. Please allow Contacts access on first launch; the app lists the reviewer's contacts as cards. If the test device has no contacts, add a few (with phone numbers and birthdays) to see the screens.

Data: contacts are read on device only and never sent anywhere. Notes, tags, favorites, and labels are stored with SwiftData in the user's private iCloud (CloudKit private database, container iCloud.com.addvalue.remindcall). There is no developer server, analytics, ads, or tracking.

How to review:
1. Contacts tab: search by name, number suffix, or Korean initials; tap a row to open the card; the green call button opens the iOS Phone app through a tel: URL. Slider/arrow buttons at the top set what is shown and the sort order.
2. Keypad tab: type digits; matching contacts appear above the keypad.
3. Favorites tab: add a favorite with the star on a card; the slider button sets which fields are shown and their order.
4. Recents tab: lists only calls started with RemindCall's call button (iOS does not allow reading the system call history).
5. Settings tab (all features are optional and off by default):
 - Post-call note reminder: after tapping the call button, a local notification arrives after the chosen delay; long-press it to type a note without opening the app.
 - Birthday reminders: local notifications for contacts' birthdays (up to 50 scheduled).
 - Unknown-number labels: the "RemindCallDirectory" Call Directory extension shows labels the user typed for numbers that are not in Contacts. Enable it in Settings > Apps > Phone > Call Blocking & Identification. The app never receives or stores incoming phone numbers.

The app does not record calls and does not read text messages or the system call log. Push notification entitlement (aps-environment) is used only by CloudKit sync; the app sends no remote notifications.
