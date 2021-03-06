package com.typelead.intellij.plugin.eta.project.module;

import com.intellij.ide.util.projectWizard.EmptyModuleBuilder;
import com.intellij.openapi.module.ModuleType;
import com.typelead.intellij.plugin.eta.resources.EtaIcons;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;

public class EtlasModuleType extends ModuleType<EmptyModuleBuilder> {

  private static String ID = "ETA_ETLAS_MODULE";

  public static EtlasModuleType INSTANCE = new EtlasModuleType();

  private EtlasModuleType() {
    super(ID);
  }

  @NotNull
  @Override
  public EmptyModuleBuilder createModuleBuilder() {
    return new EmptyModuleBuilder();
  }

  @NotNull
  @Override
  public String getName() {
    return "Etlas Module";
  }

  @NotNull
  @Override
  public String getDescription() {
    return "Etlas modules are used for developing Eta projects using " +
           "the Eta build tool.";
  }

  @Override
  public Icon getNodeIcon(boolean isOpened) {
    return EtaIcons.FILE;
  }
}
