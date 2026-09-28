// Every user-facing string in one place, so voice can be audited and
// changed in one pass. Register: professional, direct, no em-dashes, no
// gamified language on the educator side.

export const S = {
  errors: {
    generic: 'Something went wrong on our side. Try again.',
    sessionExpired: 'Your session expired. Sign in again to continue.',
    offline: 'You appear to be offline. Check your connection and try again.',
    aggregateOnly:
      'This class reports aggregate data only, so per-student views are off.',
    notFaculty: 'Your account does not have faculty access to this class.',
    badSessionCode:
      'That code does not match a running session. Check it with your instructor.',
    displayName: 'Enter a display name between 2 and 40 characters.',
    membersOnly:
      'This session is limited to class members. Join the class in the app first.',
    questionClosed: 'That question just closed.',
    timeUp: 'Time is up for this question.',
    noAccount:
      'No Politiface account uses that email. They need to sign in to the app or console once first.',
    needsInvite: 'That account has not redeemed a faculty invite code yet.',
    needsVerification:
      'Creating classes requires instructor access. Use your invite link, or request access from the home page.',
    classNameShort: 'Class names need at least 3 characters.',
    somethingBroke:
      'This view hit an unexpected error. Reload the page; your data is safe.',
    badHandle:
      "Display names use 3 to 30 letters, numbers, spaces, or . ' - _",
    handleTaken: 'That display name is taken.',
    deletionBlocked:
      'Your classes must be transferred or deleted before your account can be.',
    deletionIncomplete:
      'Something still references this account. Contact support to finish deletion.',
    badInvite:
      'That invite link has expired or was already used. Ask the person who invited you for a new one.',
    alreadyFaculty: 'You are already a verified instructor.',
    rosterName: 'Enter your name as your professor knows it (2 to 60 characters).',
    badClassCode: 'That class code does not match a class. Check it with your professor.',
    signInToJoin: 'Sign in with your email to join as a student.',
    youTeach: 'You teach this class. Run the session from your console instead.',
  },
  empty: {
    classesTitle: 'No classes yet',
    classesHint:
      'Create your first class below. Students join it from the Politiface app with the class code.',
    studentsTitle: 'No students yet',
    studentsHint:
      'Share the class join code and students appear here as they enroll.',
    sessionsTitle: 'No live sessions yet',
    sessionsHint:
      'Run a session and students join from any browser with a code.',
    atRiskAllClear: 'No students yet.',
  },
  common: {
    exportCsv: 'Export CSV',
    exportStudentsCsv: 'Export students CSV',
    exportClassCsv: 'Export class CSV',
    signOut: 'Sign out',
    reload: 'Reload',
    cancel: 'Cancel',
    save: 'Save',
    loading: 'Loading',
    backToClass: 'Back to class',
    yourClasses: 'Your classes',
    createClass: 'Create a class',
  },
  policy: {
    perStudent: 'This class reports per-student detail to faculty.',
    pseudonymous: 'Students appear under stable pseudonyms, never names.',
    aggregateOnly: 'This class reports aggregate data only.',
  },
  pulse: {
    seeWho: 'See who',
    reteach: 'Run a reteach session',
    message: 'Message the class',
  },
  assignment: {
    assigned:
      'Practice assigned and announced to the class. Retention checks run automatically at 7 and 21 days.',
  },
  onePager: {
    preparing: 'Preparing the class summary',
    blocked:
      'Your browser blocked the summary tab. Allow pop-ups for this site and try again.',
    noData:
      'No summary is available yet. It appears after the first nightly rollup for this class.',
    failed: 'The summary could not be loaded. Try again.',
  },
  ownQuestions: {
    heading: 'Your own questions',
    hint: 'Questions you write are visible only to this class and can be used in live sessions right away.',
    add: 'Add a question',
    edit: 'Edit',
    remove: 'Remove',
    confirmRemove: 'Remove this question?',
    removeHint:
      'It leaves the question picker. Past session results that used it are kept.',
    stem: 'Question',
    domain: 'FCLE domain',
    option: 'Option',
    correct: 'Correct answer',
    explanation: 'Explanation (optional)',
    citation: 'Source (optional)',
    create: 'Save question',
    update: 'Save changes',
    editNote:
      'Saving replaces the question with a new version. Select the correct answer again to confirm it.',
    emptyTitle: 'No questions of your own yet',
    emptyHint: 'Add one and it appears in the question picker marked as yours.',
    stemShort: 'Write a question of at least 10 characters.',
    optionsShort: 'Fill in at least two options.',
    pickCorrect: 'Select the correct answer.',
    correctBlank: 'The correct answer needs text.',
  },
  signIn: {
    title: 'Sign in to Politiface',
    intro: 'We email you a 6-digit code; there is no password.',
    email: 'Email',
    sendCode: 'Send code',
    sentTo: 'We emailed a 6-digit code to',
    code: 'Code',
    submit: 'Sign in',
    differentEmail: 'Use a different email',
    sendFailed: 'We could not send a code to that address. Check the email and try again.',
    badCode: 'That code did not match. Codes expire quickly; request a new one if needed.',
    schoolEmailHint: 'Use your school email. It is the same account as the Politiface app.',
  },
  welcome: {
    title: 'You are invited to Politiface as an instructor',
    invitedBy: 'Invited by',
    invalid:
      'This invite link has expired or was already used. Ask the person who invited you for a new one.',
    verifying: 'Setting up your instructor access',
    stepProfile: 'Your profile',
    stepClass: 'Your first class',
    profileHint: 'Your display name is shown to co-faculty and on class announcements.',
    classHint: 'Students join with a code you get on the next screen. You can add more classes later.',
    next: 'Next',
    createClass: 'Create class',
    className: 'Class name',
    classNamePlaceholder: 'POS 2041, section 67',
    term: 'Term, optional',
  },
  requestAccess: {
    title: 'Are you an instructor?',
    intro:
      'Request instructor access to create classes and run live sessions. If a colleague sent you an invite link, open that link instead.',
    school: 'School',
    courses: 'Courses you teach',
    coursesPlaceholder: 'POS 2041, INR 2002',
    note: 'Anything we should know (optional)',
    submit: 'Request access',
    pending: 'Request sent. You can create classes as soon as it is approved; this page updates on its own.',
    denied: 'Your request was not approved. Reply to your invite or contact support@politiface.app.',
    studentInstead: 'Are you a student? Join a live session with the code your professor shows.',
  },
  student: {
    title: 'Your classes',
    none: 'You have not joined a class yet.',
    joinSession: 'Join a live session',
    sessionCode: 'Session code',
    join: 'Join',
    joinClass: 'Join a class',
    classCode: 'Class code',
    rosterName: 'Your name as your professor knows it',
    joined: 'You joined the class.',
    getApp: 'Practice between sessions with the Politiface app, supplemental practice you choose.',
  },
  join: {
    title: 'Join a live session',
    with: 'with',
    signInIntro: 'Sign in to join. Use your school email; it is the same account as the Politiface app.',
    joinAs: 'Join as',
    firstTimeName: 'Your name as your professor knows it',
    joinClass: 'Join',
    notYou: 'Not you? Sign out',
    guest: 'Join without signing in',
    guestNote: 'Guest answers count for this session only and are not added to your class record.',
    guestName: 'Your name',
  },
  staffTools: {
    inviteTitle: 'Invite an instructor',
    inviteHint: 'Creates a single-use link that verifies them and walks them into their first class. Links expire in 14 days.',
    recipient: 'Their email (optional, for your records)',
    note: 'Note (optional)',
    mint: 'Create invite link',
    inviteLinkLabel: 'Invite link',
    copy: 'Copy link',
    copied: 'Copied',
    requestsTitle: 'Instructor requests',
    noRequests: 'No pending requests.',
    approve: 'Approve',
    deny: 'Deny',
  },
  provenance: {
    verified: 'Server-verified',
  },
  account: {
    title: 'Account',
    profileHeading: 'Profile',
    displayName: 'Display name',
    displayNameHint:
      "Shown to co-faculty and on announcements. 3 to 30 letters, numbers, spaces, or . ' - _",
    school: 'School',
    saved: 'Saved.',
    emailHeading: 'Sign-in email',
    changeEmail: 'Change email',
    newEmail: 'New email',
    emailPending:
      'Check both inboxes. Confirmation links went to the old and the new address; the change completes when both are confirmed.',
    sessionsHeading: 'Sessions',
    signOutEverywhere: 'Sign out of all devices',
    signOutEverywhereHint:
      'Use this if you signed in on a shared or lost device. Every device, this one included, then needs a fresh emailed code.',
    dangerHeading: 'Danger zone',
    deleteAccount: 'Delete account',
    deleteWarning:
      'This permanently deletes your account, profile, and activity history. It cannot be undone.',
    deleteConfirmPrompt: 'Type DELETE to confirm.',
    blockedIntro:
      'These classes still have members, so your account cannot be deleted yet. Transfer each class to a co-faculty, or remove it first.',
    transferOwnership: 'Transfer ownership',
    transferTo: 'New owner',
    noCoFaculty:
      'No co-faculty on this class yet. Add one in the class Settings tab, then transfer ownership here.',
  },
} as const
