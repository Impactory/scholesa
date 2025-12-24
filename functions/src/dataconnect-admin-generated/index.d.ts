import { ConnectorConfig, DataConnect, OperationOptions, ExecuteOperationResponse } from 'firebase-admin/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;


export interface Attendance_Key {
  playerId: UUIDString;
  eventId: UUIDString;
  __typename?: 'Attendance_Key';
}

export interface CreateDemoUserData {
  user_insert: User_Key;
}

export interface Event_Key {
  id: UUIDString;
  __typename?: 'Event_Key';
}

export interface ListAllTeamsData {
  teams: ({
    id: UUIDString;
    name: string;
    description?: string | null;
  } & Team_Key)[];
}

export interface ListMyTeamsData {
  teams: ({
    id: UUIDString;
    name: string;
    description?: string | null;
  } & Team_Key)[];
}

export interface PerformanceStat_Key {
  statType: string;
  playerId: UUIDString;
  eventId: UUIDString;
  __typename?: 'PerformanceStat_Key';
}

export interface Player_Key {
  id: UUIDString;
  __typename?: 'Player_Key';
}

export interface Team_Key {
  id: UUIDString;
  __typename?: 'Team_Key';
}

export interface UpdatePlayerJerseyNumberData {
  player_update?: Player_Key | null;
}

export interface UpdatePlayerJerseyNumberVariables {
  id: UUIDString;
  jerseyNumber: number;
}

export interface User_Key {
  id: UUIDString;
  __typename?: 'User_Key';
}

/** Generated Node Admin SDK operation action function for the 'CreateDemoUser' Mutation. Allow users to execute without passing in DataConnect. */
export function createDemoUser(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateDemoUserData>>;
/** Generated Node Admin SDK operation action function for the 'CreateDemoUser' Mutation. Allow users to pass in custom DataConnect instances. */
export function createDemoUser(options?: OperationOptions): Promise<ExecuteOperationResponse<CreateDemoUserData>>;

/** Generated Node Admin SDK operation action function for the 'ListAllTeams' Query. Allow users to execute without passing in DataConnect. */
export function listAllTeams(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<ListAllTeamsData>>;
/** Generated Node Admin SDK operation action function for the 'ListAllTeams' Query. Allow users to pass in custom DataConnect instances. */
export function listAllTeams(options?: OperationOptions): Promise<ExecuteOperationResponse<ListAllTeamsData>>;

/** Generated Node Admin SDK operation action function for the 'UpdatePlayerJerseyNumber' Mutation. Allow users to execute without passing in DataConnect. */
export function updatePlayerJerseyNumber(dc: DataConnect, vars: UpdatePlayerJerseyNumberVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdatePlayerJerseyNumberData>>;
/** Generated Node Admin SDK operation action function for the 'UpdatePlayerJerseyNumber' Mutation. Allow users to pass in custom DataConnect instances. */
export function updatePlayerJerseyNumber(vars: UpdatePlayerJerseyNumberVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdatePlayerJerseyNumberData>>;

/** Generated Node Admin SDK operation action function for the 'ListMyTeams' Query. Allow users to execute without passing in DataConnect. */
export function listMyTeams(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyTeamsData>>;
/** Generated Node Admin SDK operation action function for the 'ListMyTeams' Query. Allow users to pass in custom DataConnect instances. */
export function listMyTeams(options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyTeamsData>>;

