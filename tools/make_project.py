#!/usr/bin/env python3
"""生成 ousic.xcodeproj（不依赖 Xcode / XcodeGen，纯文本生成）。"""
import hashlib, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "ousic"
BUNDLE_ID = "com.ousic.game"

SWIFT_FILES = {
    "App": ["OusicApp.swift"],
    "Core": ["Chart.swift", "ChartStore.swift", "GameResult.swift", "GameSettings.swift"],
    "Audio": ["MusicPlayer.swift", "SongSynth.swift"],
    "Game": ["GameController.swift", "GameScene.swift", "GameView.swift"],
    "Views": ["ChartFormatHelpView.swift", "HomeView.swift", "ResultView.swift",
              "SettingsView.swift", "SongDetailView.swift", "Theme.swift"],
}
RESOURCE_FILES = [
    ("Resources", "Assets.xcassets", "folder.assetcatalog"),
    ("Resources", "Charts", "folder"),
]

TARGET_ID = "A10000000000000000000001"
PROJECT_ID = "A10000000000000000000002"
MAIN_GROUP_ID = "A10000000000000000000003"
PRODUCTS_GROUP_ID = "A10000000000000000000004"
PRODUCT_ID = "A10000000000000000000005"
SOURCES_PHASE_ID = "A10000000000000000000006"
FRAMEWORKS_PHASE_ID = "A10000000000000000000007"
RESOURCES_PHASE_ID = "A10000000000000000000008"
PROJECT_CFG_LIST = "A10000000000000000000009"
TARGET_CFG_LIST = "A1000000000000000000000A"
PROJECT_DEBUG = "A1000000000000000000000B"
PROJECT_RELEASE = "A1000000000000000000000C"
TARGET_DEBUG = "A1000000000000000000000D"
TARGET_RELEASE = "A1000000000000000000000E"


def oid(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def quote(value):
    if value.startswith("$") or "/" in value or "*" in value or value == "" or " " in value:
        return '"%s"' % value
    return value


swift_refs = {}      # (group, filename) -> (file_id, build_id)
resource_refs = {}   # (group, filename) -> (file_id, build_id)

objects_build = []
objects_ref = []

for group, files in SWIFT_FILES.items():
    for name in files:
        fid = oid("ref:%s/%s" % (group, name))
        bid = oid("build:%s/%s" % (group, name))
        swift_refs[(group, name)] = (fid, bid)
        objects_build.append(
            "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };" % (bid, name, fid, name))
        objects_ref.append(
            "\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = %s; sourceTree = \"<group>\"; };" % (fid, name, name))

for group, name, ftype in RESOURCE_FILES:
    fid = oid("ref:%s/%s" % (group, name))
    bid = oid("build:%s/%s" % (group, name))
    resource_refs[(group, name)] = (fid, bid)
    objects_build.append(
        "\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };" % (bid, name, fid, name))
    objects_ref.append(
        "\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = \"<group>\"; };" % (fid, name, ftype, name))

info_ref = oid("ref:Info.plist")
objects_ref.append(
    '\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };' % info_ref)


# 分组
groups = {}
group_ids = {"App": oid("group:App"), "Core": oid("group:Core"), "Audio": oid("group:Audio"),
             "Game": oid("group:Game"), "Views": oid("group:Views"), "Resources": oid("group:Resources")}

for group, files in SWIFT_FILES.items():
    children = ",\n".join("\t\t\t\t%s /* %s */" % (swift_refs[(group, name)][0], name) for name in files)
    groups[group] = (
        '\t\t%s /* %s */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s,\n\t\t\t);\n\t\t\tpath = %s;\n\t\t\tsourceTree = "<group>";\n\t\t};'
        % (group_ids[group], group, children, group))

res_children = ",\n".join("\t\t\t\t%s /* %s */" % (resource_refs[(group, name)][0], name) for group, name, _ in RESOURCE_FILES)
groups["Resources"] = (
    '\t\t%s /* Resources */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s,\n\t\t\t);\n\t\t\tpath = Resources;\n\t\t\tsourceTree = "<group>";\n\t\t};'
    % (group_ids["Resources"], res_children))

main_children = [group_ids[g] for g in ["App", "Core", "Audio", "Game", "Views", "Resources"]]
main_children.append(info_ref)

main_group = (
    '\t\t%s = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s,\n\t\t\t);\n\t\t\tpath = ousic;\n\t\t\tsourceTree = "<group>";\n\t\t};'
    % (MAIN_GROUP_ID, ",\n".join("\t\t\t\t%s" % c for c in main_children)))

products_group = (
    '\t\t%s /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t%s /* ousic.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t};'
    % (PRODUCTS_GROUP_ID, PRODUCT_ID))

source_files = ",\n".join("\t\t\t\t%s /* %s in Sources */" % (swift_refs[(g, n)][1], n)
                          for g, files in SWIFT_FILES.items() for n in files)
resource_files = ",\n".join("\t\t\t\t%s /* %s in Resources */" % (resource_refs[(g, n)][1], n)
                            for g, n, _ in RESOURCE_FILES)

project_build_settings = """				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				SDKROOT = iphoneos;
				SWIFT_VERSION = 5.0;"""

project_debug = project_build_settings + """
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

project_release = project_build_settings + """
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;"""

target_common = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = ousic/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %s;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_STRICT_CONCURRENCY = minimal;
				TARGETED_DEVICE_FAMILY = "1,2";""" % BUNDLE_ID

pbx = """// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
%s
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		%s /* ousic.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ousic.app; sourceTree = BUILT_PRODUCTS_DIR; };
%s
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		%s /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		%s
		%s
		%s
		%s
		%s
		%s
		%s
		%s
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		%s /* ousic */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = %s /* Build configuration list for PBXNativeTarget "ousic" */;
			buildPhases = (
				%s /* Sources */,
				%s /* Frameworks */,
				%s /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = ousic;
			productName = ousic;
			productReference = %s /* ousic.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		%s /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					%s = {
						CreatedOnToolsVersion = 16.0;
					};
				};
			};
			buildConfigurationList = %s /* Build configuration list for PBXProject "ousic" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = %s;
			productRefGroup = %s /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				%s /* ousic */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		%s /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
%s
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		%s /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
%s
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		%s /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
%s
			};
			name = Debug;
		};
		%s /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
%s
			};
			name = Release;
		};
		%s /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
%s
			};
			name = Debug;
		};
		%s /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
%s
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		%s /* Build configuration list for PBXProject "ousic" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				%s /* Debug */,
				%s /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		%s /* Build configuration list for PBXNativeTarget "ousic" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				%s /* Debug */,
				%s /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = %s /* Project object */;
}
""" % (
    "\n".join(objects_build),
    PRODUCT_ID,
    "\n".join(objects_ref),
    FRAMEWORKS_PHASE_ID,
    main_group,
    products_group,
    groups["App"], groups["Core"], groups["Audio"], groups["Game"], groups["Views"], groups["Resources"],
    TARGET_ID, TARGET_CFG_LIST, SOURCES_PHASE_ID, FRAMEWORKS_PHASE_ID, RESOURCES_PHASE_ID, PRODUCT_ID,
    PROJECT_ID, TARGET_ID, PROJECT_CFG_LIST, MAIN_GROUP_ID, PRODUCTS_GROUP_ID, TARGET_ID,
    RESOURCES_PHASE_ID, resource_files,
    SOURCES_PHASE_ID, source_files,
    PROJECT_DEBUG, project_debug,
    PROJECT_RELEASE, project_release,
    TARGET_DEBUG, target_common,
    TARGET_RELEASE, target_common,
    PROJECT_CFG_LIST, PROJECT_DEBUG, PROJECT_RELEASE,
    TARGET_CFG_LIST, TARGET_DEBUG, TARGET_RELEASE,
    PROJECT_ID,
)

scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%s"
               BuildableName = "ousic.app"
               BlueprintName = "ousic"
               ReferencedContainer = "container:ousic.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%s"
            BuildableName = "ousic.app"
            BlueprintName = "ousic"
            ReferencedContainer = "container:ousic.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%s"
            BuildableName = "ousic.app"
            BlueprintName = "ousic"
            ReferencedContainer = "container:ousic.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""" % (TARGET_ID, TARGET_ID, TARGET_ID)


def main():
    proj_dir = os.path.join(ROOT, "ousic.xcodeproj")
    os.makedirs(os.path.join(proj_dir, "xcshareddata", "xcschemes"), exist_ok=True)
    with open(os.path.join(proj_dir, "project.pbxproj"), "w", encoding="utf-8") as f:
        f.write(pbx)
    with open(os.path.join(proj_dir, "xcshareddata", "xcschemes", "ousic.xcscheme"), "w", encoding="utf-8") as f:
        f.write(scheme)
    print("生成完成：ousic.xcodeproj")


if __name__ == "__main__":
    main()
