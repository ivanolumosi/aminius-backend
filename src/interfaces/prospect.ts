// interfaces/prospect.ts

export interface Prospect {
  ProspectId: string;
  AgentId: string;
  FirstName: string;
  Surname?: string;
  LastName?: string;
  PhoneNumber?: string;
  Email?: string;
  Notes?: string;
  CreatedDate: Date;
  ModifiedDate: Date;
  IsActive: boolean;
}

export interface ProspectExternalPolicy {
  ExtPolicyId: string;
  ProspectId: string;
  CompanyName: string;
  PolicyNumber?: string;
  PolicyType?: string;
  ExpiryDate?: Date;
  Notes?: string;
  CreatedDate: Date;
  ModifiedDate: Date;
  IsActive: boolean;
}

export interface ProspectStatistics {
  TotalProspects: number;
  ProspectsWithPolicies: number;
  ExpiringIn7Days: number;
  ExpiringIn30Days: number;
  ExpiredPolicies: number;
}

export interface ExpiringProspectPolicy {
  ProspectId: string;
  FullName: string;
  PhoneNumber?: string;
  Email?: string;
  PolicyType?: string;
  CompanyName: string;
  ExpiryDate: Date;
  DaysUntilExpiry: number;
  Priority: 'High' | 'Medium' | 'Low';
}

export interface AddProspectRequest {
  AgentId: string;
  FirstName: string;
  Surname?: string;
  LastName?: string;
  PhoneNumber?: string;
  Email?: string;
  Notes?: string;
}

export interface AddProspectResponse {
  Success: boolean;
  Message: string;
  ProspectId?: string;
}

export interface AddProspectPolicyRequest {
  ProspectId: string;
  CompanyName: string;
  PolicyNumber?: string;
  PolicyType?: string;
  ExpiryDate?: Date;
  Notes?: string;
}

export interface AddProspectPolicyResponse {
  Success: boolean;
  Message: string;
  ExtPolicyId?: string;
}

export interface UpdateProspectRequest {
  ProspectId: string;
  FirstName: string;
  Surname?: string;
  LastName?: string;
  PhoneNumber?: string;
  Email?: string;
  Notes?: string;
}

export interface ConvertProspectToClientRequest {
  ProspectId: string;
  Address?: string;
  NationalId?: string;
  DateOfBirth?: Date;
}

export interface ConvertProspectToClientResponse {
  Success: boolean;
  Message: string;
  ClientId?: string;
}

export interface AutoCreateRemindersResponse {
  Success: boolean;
  Message: string;
  RemindersCreated: number;
}