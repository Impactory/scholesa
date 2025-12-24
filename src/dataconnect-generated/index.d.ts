import { ConnectorConfig, DataConnect, QueryRef, QueryPromise, MutationRef, MutationPromise } from 'firebase/data-connect';

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

interface CreateDemoUserRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateDemoUserData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<CreateDemoUserData, undefined>;
  operationName: string;
}
export const createDemoUserRef: CreateDemoUserRef;

export function createDemoUser(): MutationPromise<CreateDemoUserData, undefined>;
export function createDemoUser(dc: DataConnect): MutationPromise<CreateDemoUserData, undefined>;

interface ListAllTeamsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListAllTeamsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListAllTeamsData, undefined>;
  operationName: string;
}
export const listAllTeamsRef: ListAllTeamsRef;

export function listAllTeams(): QueryPromise<ListAllTeamsData, undefined>;
export function listAllTeams(dc: DataConnect): QueryPromise<ListAllTeamsData, undefined>;

interface UpdatePlayerJerseyNumberRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdatePlayerJerseyNumberVariables): MutationRef<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdatePlayerJerseyNumberVariables): MutationRef<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
  operationName: string;
}
export const updatePlayerJerseyNumberRef: UpdatePlayerJerseyNumberRef;

export function updatePlayerJerseyNumber(vars: UpdatePlayerJerseyNumberVariables): MutationPromise<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
export function updatePlayerJerseyNumber(dc: DataConnect, vars: UpdatePlayerJerseyNumberVariables): MutationPromise<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;

interface ListMyTeamsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyTeamsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListMyTeamsData, undefined>;
  operationName: string;
}
export const listMyTeamsRef: ListMyTeamsRef;

export function listMyTeams(): QueryPromise<ListMyTeamsData, undefined>;
export function listMyTeams(dc: DataConnect): QueryPromise<ListMyTeamsData, undefined>;

