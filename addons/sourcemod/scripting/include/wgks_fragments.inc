#if defined _wgks_fragments_included_
  #endinput
#endif
#define _wgks_fragments_included_

native void Fragments_SetClientKnifeCountFragments(int iClient, int iKnifeIndex, int iAmount);
native int Fragments_GetClientKnifeCountFragments(int iClient, int iKnifeIndex);
native int Fragments_GetReqKnifeCountFragments(int iKnifeIndex);

public SharedPlugin __pl_wgks_fragments  =
{
	name = "wgks_fragments",
	file = "wgks_fragments.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_wgks_fragments_SetNTVOptional()
{
	MarkNativeAsOptional("Fragments_GetClientKnifeCountFragments");
	MarkNativeAsOptional("Fragments_SetClientKnifeCountFragments");
	MarkNativeAsOptional("Fragments_GetReqKnifeCountFragments");
}
#endif