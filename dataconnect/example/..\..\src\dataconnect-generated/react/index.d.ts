import { CreateDemoUserData, ListAllTeamsData, UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables, ListMyTeamsData } from '../';
import { UseDataConnectQueryResult, useDataConnectQueryOptions, UseDataConnectMutationResult, useDataConnectMutationOptions} from '@tanstack-query-firebase/react/data-connect';
import { UseQueryResult, UseMutationResult} from '@tanstack/react-query';
import { DataConnect } from 'firebase/data-connect';
import { FirebaseError } from 'firebase/app';


export function useCreateDemoUser(options?: useDataConnectMutationOptions<CreateDemoUserData, FirebaseError, void>): UseDataConnectMutationResult<CreateDemoUserData, undefined>;
export function useCreateDemoUser(dc: DataConnect, options?: useDataConnectMutationOptions<CreateDemoUserData, FirebaseError, void>): UseDataConnectMutationResult<CreateDemoUserData, undefined>;

export function useListAllTeams(options?: useDataConnectQueryOptions<ListAllTeamsData>): UseDataConnectQueryResult<ListAllTeamsData, undefined>;
export function useListAllTeams(dc: DataConnect, options?: useDataConnectQueryOptions<ListAllTeamsData>): UseDataConnectQueryResult<ListAllTeamsData, undefined>;

export function useUpdatePlayerJerseyNumber(options?: useDataConnectMutationOptions<UpdatePlayerJerseyNumberData, FirebaseError, UpdatePlayerJerseyNumberVariables>): UseDataConnectMutationResult<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
export function useUpdatePlayerJerseyNumber(dc: DataConnect, options?: useDataConnectMutationOptions<UpdatePlayerJerseyNumberData, FirebaseError, UpdatePlayerJerseyNumberVariables>): UseDataConnectMutationResult<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;

export function useListMyTeams(options?: useDataConnectQueryOptions<ListMyTeamsData>): UseDataConnectQueryResult<ListMyTeamsData, undefined>;
export function useListMyTeams(dc: DataConnect, options?: useDataConnectQueryOptions<ListMyTeamsData>): UseDataConnectQueryResult<ListMyTeamsData, undefined>;
