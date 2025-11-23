// Code by Hao Nguyen, 991521091

enum Path: String, CaseIterable, Codable {
    case startToFinish = "Start → Stop 1 → Stop 2 → Destination";
    case startToStop1 = "Start → Stop 1";
    case stop1ToStop2 = "Stop 1 → Stop 2";
    case stop2ToDestination = "Stop 2 → Destination";
}
