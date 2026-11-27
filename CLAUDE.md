# RemindCall

## 개요·기술 스택
- 통화 전·중에 상대의 번호, 생일, 메모, 연락 기록을 카드로 보여 주는 앱. 기획은 `PLAN.md`.
- SwiftUI, 최소 iOS 17, SwiftData + CloudKit(개인 DB, 컨테이너 `iCloud.com.addvalue.remindcall`)
- 번들 ID `com.addvalue.remindcall`, 팀 `A7QB8PT33N`
- 연락처는 `Contacts` 프레임워크로 읽기만 한다. 앱 데이터는 별도 모델에 저장한다.

## 폴더 구조
- `RemindCall/Models` SwiftData 모델, `PhoneKey`, 컨테이너 생성
- `RemindCall/Services` 연락처 로딩·검색(`ContactsStore`)
- `RemindCall/Views` 연락처 목록, 통화 화면 스타일 카드(`CallCardView`, `Cards`)
- `RemindCall.entitlements` iCloud(CloudKit), 푸시

## 규칙
- iOS가 허용하지 않는 기능은 만들지 않는다: 시스템 통화 기록·문자 읽기, 수신 번호 가로채기, 통화 화면 오버레이, 통화 녹음, 연락처 기본 메모 필드.
- 통화는 `tel://`로 시스템 전화 앱에 넘긴다. 음소거·키패드 같은 통화 제어 버튼은 만들지 않는다.
- 통화 기록은 앱에서 건 통화만 저장하고, 화면에 그렇게 밝힌다.
- CloudKit 조건: 모델 속성은 모두 기본값을 가지고 unique 제약을 쓰지 않는다.
- 앱 데이터와 연락처는 번호 키(`PhoneKey.make`: 숫자만, 82→0)로 연결한다. `CNContact.identifier`는 기기마다 달라 키로 쓰지 않는다.
- 연락처 원본을 서버로 보내거나 수정하지 않는다.
- 다국어: 한국어(원본)·영어·일본어·중국어 간체. 문구는 `Localizable.xcstrings`(권한 문구는 `InfoPlist.xcstrings`)에 en·ja·zh-Hans를 함께 추가한다. 화면 문구가 아닌 String 값은 `L(...)`(고른 앱 언어 번들), 날짜 형식은 `.locale(LanguageManager.shared.locale)`로 쓴다. 언어는 설정 탭에서 고르고 `LanguageManager`가 AppleLanguages 저장과 Bundle 문자열 조회 전환으로 즉시 적용한다.

## 명령어·현재 상태
- 스킴·타깃: `RemindCall`, 프로젝트 `RemindCall.xcodeproj` (폴더 동기화 그룹: `RemindCall/` 안에 파일을 만들면 자동 포함)
- 기기 빌드: `xcodebuild ... -destination 'id=<UDID>' -allowProvisioningUpdates` (xcodebuild용 UDID는 `-showdestinations`로, devicectl용 ID는 `devicectl list devices`로 확인)
- 확장: `RemindCallDirectory`(Call Directory, App Group `group.com.addvalue.remindcall`) 타깃. 프로젝트 파일은 pbxproj 쓰기 규칙 때문에 생성 스크립트(Python)로 만들었다. 타깃을 바꿀 때는 스크립트를 고쳐 다시 생성한다.
- 설정 탭(켜기/끄기): 통화 후 메모 알림, 생일 알림(최대 50개 예약), 모르는 번호 이름표. 기본값은 모두 꺼짐.
- 제출 값(App Store Connect, 앱 ID 6839308482): 카테고리 생산성/유틸리티, 연령 4+, 무료, 저작권 2026 BS Jeon, 지원 URL=GitHub 저장소, 처리방침 `outinletter.github.io/privacy-policy/remindcall.html`, 프라이버시 "수집 안 함". 문구·심사 노트는 `app-store/METADATA.md`, 광고용 스크린샷은 `app-store/screenshots/`(1206×2622, 개인정보 일반화본).
- 업로드: `xcodebuild archive` 후 `-exportArchive`(method app-store-connect, destination upload).
- 현재: 1.0.1 (2) 승인됨(배포 준비됨). 1.1 (3) 2026-11-27 심사 제출(4개 언어 메타데이터·스크린샷). 스토어 스크린샷은 `-demoMode YES -appLanguage <code>` 실행 인자로 시연 데이터를 띄워 캡처. 다음: 심사 결과 대응, 생성 스크립트의 버전을 1.1 (3)으로 맞출 것.
- 시뮬레이터는 쓰지 않는다. 실기기 설치는 "설치" 요청 때만 한다.
